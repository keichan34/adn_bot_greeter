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

    if nice do
      Logger.info "Post from #{username}, NR #{nice["rank"]}"
    end

    {:noreply, state}
  end
end
