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
    {:ok, nice} = Nice.user(username)

    case nice do
      %{"rank" => rank} when rank >= 1.7 and rank <= 2.0 ->
        Logger.info "=> #{username} NR #{rank} (Bot or not?)"
      %{"rank" => rank} ->
        Logger.info "=> #{username} NR #{rank}"
      nil ->
        Logger.info "=> #{username} NR 0.0"
    end
    {:noreply, state}
  end
end
