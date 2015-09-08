defmodule AdnBotGreeter.GlobalStreamHandler do
  use GenServer

  alias AdnBotGreeter.GlobalStream

  import AdnBotGreeter.GlobalProcessor, only: [process_message: 1]

  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    Kernel.send self, :start_stream
    {:ok, %{buffer: "", stream_ref: nil}}
  end

  def handle_info(:start_stream, state) do
    {:ok, endpoint} = GlobalStream.stream_endpoint

    {:ok, %HTTPoison.AsyncResponse{id: ref}} =
      HTTPoison.get(
        endpoint,
        [
          {"User-Agent", "adnbotgreeter-0"}
        ],
        stream_to: self,
        timeout: 5000,
        recv_timeout: 60000)

    {:noreply, %{state | stream_ref: ref}}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: 200}, state) do
    Logger.info "[Stream] Started."
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: error}, state) do
    # Ignore an error.
    Logger.info "[Stream] Stream failed with error: #{error}"
    {:stop, :normal, state}
  end

  # Ignore headers.
  def handle_info(%HTTPoison.AsyncHeaders{headers: _}, state) do
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: data}, state) do
    buffer = state[:buffer] <> data
    chunks = String.split(buffer, "\r\n")
    buffer = List.last(chunks) || ""
    chunks = List.delete_at(chunks, -1)
    Enum.each(chunks, &process_message(&1))

    {:noreply, %{state | buffer: buffer}}
  end

  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    Logger.info "[Stream] Disconnected by server."
    {:stop, :normal, state}
  end

  def handle_info(%HTTPoison.Error{reason: reason}, state) do
    Logger.info "[Stream] Connection failed: #{inspect reason}"
    {:stop, :normal, state}
  end
end
