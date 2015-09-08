defmodule AdnBotGreeter.Nice do
  use GenServer

  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def user(id) do
    GenServer.call(__MODULE__, {:query_user, id})
  end

  def reload_data do
    GenServer.call(__MODULE__, :reload_data)
  end

  defp load_data(users) do
    GenServer.call(__MODULE__, {:load_data, users})
  end

  def init(_) do
    Kernel.send self, :trigger_reload
    {:ok, %{users: nil}}
  end

  def handle_info(:trigger_reload, state) do
    spawn_link(fn ->
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} =
        HTTPoison.get(
          "https://api.nice.social/user/nicesummary?nicerank=0.1",
          [
            {"User-Agent", "adnbotgreeter-0"}
          ],
          timeout: 1000,
          recv_timeout: 30000
        )

      decoded = Poison.Parser.parse!(body)
      data = decoded["data"]

      users = data
      |> Enum.reduce(%{}, fn(x, acc) ->
        user = Map.drop(x, ~w(user_id))
        acc
        |> Map.put(x["user_id"], user)
      end)

      load_data(users)

      int = 360_000 + :crypto.rand_uniform(-50, 50) * 10
      Process.send_after __MODULE__, :trigger_reload, int
    end)

    {:noreply, state}
  end

  def handle_call(:reload_data, _from, state) do
    {:noreply, state} = handle_info(:trigger_reload, state)
    {:reply, :ok, state}
  end

  def handle_call({:load_data, users}, _from, state) do
    state = %{state | users: users}
    Logger.info "[Nice] Loaded."

    {:reply, :ok, state}
  end

  def handle_call({:query_user, _}, _from, %{users: nil} = state),
    do: {:reply, {:error, :data_not_loaded_yet}, state}

  def handle_call({:query_user, id}, _from, state) when is_binary(id),
    do: handle_call({:query_user, String.to_integer(id)}, _from, state)

  def handle_call({:query_user, id}, _from, %{users: users} = state) do
    case Map.fetch(users, id) do
      {:ok, user} ->
        {:reply, {:ok, user}, state}
      :error ->
        {user, state} = single_lookup(id, state)
        {:reply, {:ok, user}, state}
    end
  end

  defp single_lookup(id, state) do
    {:ok, %HTTPoison.Response{body: body, status_code: 200}} =
      HTTPoison.get(
        "https://api.nice.social/user/nicerank?ids=#{id}",
        [
          {"User-Agent", "adnbotgreeter-0"}
        ],
        timeout: 1000,
        recv_timeout: 1000
        )

    decoded = Poison.Parser.parse!(body)
    data = decoded["data"]

    if is_list(data) and length(data) >= 1 do
      datum = List.first(data)
      user = Map.drop(datum, ~w(user_id))
      users = state[:users]
      |> Map.put(datum["user_id"], user)

      {user, %{state | users: users}}
    else
      {nil, state}
    end
  end
end
