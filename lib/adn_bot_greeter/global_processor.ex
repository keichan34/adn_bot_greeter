defmodule AdnBotGreeter.GlobalProcessor do
  use GenServer

  alias AdnBotGreeter.Nice

  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def process_message(message) do
    GenServer.cast(__MODULE__, {:process_message, message})
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_cast({:process_message, message}, state) do
    decoded = Poison.Parser.parse!(message)

    username = decoded["data"]["user"]["username"]
    user_id = decoded["data"]["user"]["id"]

    case Nice.user(user_id) do
      {:ok, %{"rank" => rank}} when rank >= 1.7 and rank <= 2.0 ->
        Logger.info "=> #{username} NR #{rank} (Bot or not?)"
      {:ok, %{"rank" => rank}} ->
        Logger.info "=> #{username} NR #{rank}"
      {:ok, nil} ->
        Logger.info "=> #{username} NR 0.0"
      {:error, _} ->
        Logger.info "=> #{username} NR ???"
    end
    {:noreply, state}
  end
end
