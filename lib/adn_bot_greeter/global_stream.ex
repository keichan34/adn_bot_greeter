defmodule AdnBotGreeter.GlobalStream do
  use GenServer

  alias AdnBotGreeter.AuthorizationWorker

  require Logger

  import AdnBotGreeter.GlobalProcessor, only: [process_message: 1]

  @stream_key "adnbotgreeter-stream"

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    Kernel.send self, :initialize
    {:ok, %{stream: nil, stream_ref: nil, buffer: ""}}
  end

  def handle_info(:initialize, state) do
    params = URI.encode_query(%{"key" => @stream_key})
    {:ok, %HTTPoison.Response{body: body, status_code: 200}} =
      HTTPoison.get(
        "https://api.app.net/streams?#{params}",
        [
          {"User-Agent", "adnbotgreeter-0"},
          {"Authorization", "Bearer #{AuthorizationWorker.token}"},
        ])

    decoded = Poison.Parser.parse!(body)
    if length(decoded["data"]) >= 1 do
      state = %{state | stream: List.first(decoded["data"]) }
    else
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} =
        HTTPoison.post(
          "https://api.app.net/streams",
          Poison.encode!(%{
            "object_types" => ["post"],
            "type" => "long_poll",
            "key" => @stream_key
          }),
          [
            {"User-Agent", "adnbotgreeter-0"},
            {"Authorization", "Bearer #{AuthorizationWorker.token}"},
            {"Content-Type", "application/json"}
          ])
      decoded = Poison.Parser.parse!(body)
      state = %{state | stream: decoded["data"]}
    end

    state = start_stream(state)

    {:noreply, state}
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
    IO.puts "[Stream] Disconnected by server."
    {:stop, :normal, state}
  end

  def handle_info(%HTTPoison.Error{reason: reason}, state) do
    IO.puts "[Stream] Connection failed: #{inspect reason}"
    {:stop, :normal, state}
  end

  def terminate(_reason, _state) do
    HTTPoison.delete!(
      "https://api.app.net/streams",
      [
        {"User-Agent", "adnbotgreeter-0"},
        {"Authorization", "Bearer #{AuthorizationWorker.token}"}
      ])
    :ok
  end

  defp start_stream(state) do
    {:ok, %HTTPoison.AsyncResponse{id: ref}} =
      HTTPoison.get(
        state[:stream]["endpoint"],
        [
          {"User-Agent", "adnbotgreeter-0"}
        ],
        stream_to: self)

    %{state | stream_ref: ref}
  end
end
