defmodule AdnBotGreeter.Nice do
  use GenServer

  import Logger

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def user(name) do
    GenServer.call(__MODULE__, {:query_user, name})
  end

  def init(_) do
    Kernel.send self, :trigger_reload
    {:ok, %{users: nil}}
  end

  def handle_info(:trigger_reload, state) do
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
      user = Map.drop(x, ~w(user_id name))
      acc
      |> Map.put(x["user_id"], user)
      |> Map.put(x["name"], user)
    end)

    state = %{state | users: users}

    Logger.info "[Nice] Loaded."

    {:noreply, state}
  end

  def handle_call({:query_user, _}, _from, %{users: nil} = state),
    do: {:reply, {:error, :data_not_loaded_yet}, state}

  def handle_call({:query_user, name}, _from, %{users: users} = state) do
    case Map.fetch(users, name) do
      {:ok, user} ->
        {:reply, {:ok, user}, state}
      :error ->
        {:reply, {:ok, nil}, state}
    end
  end
end
