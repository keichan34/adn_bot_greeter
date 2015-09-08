defmodule AdnBotGreeter.GlobalStream do
  use GenServer

  alias AdnBotGreeter.AuthorizationWorker

  require Logger

  @stream_key "adnbotgreeter-stream"

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def stream_endpoint do
    GenServer.call(__MODULE__, :stream_endpoint)
  end

  def init(_) do
    Kernel.send self, :initialize
    {:ok, %{stream: nil}}
  end

  def handle_call(:stream_endpoint, _from, state) do
    out = if state[:stream] do
      {:ok, state[:stream]["endpoint"]}
    else
      {:error, :not_loaded}
    end
    {:reply, out, state}
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

    {:noreply, state}
  end

  def terminate(_reason, _state) do
    Logger.fatal "[Stream] Tearing down..."
    HTTPoison.delete!(
      "https://api.app.net/streams",
      [
        {"User-Agent", "adnbotgreeter-0"},
        {"Authorization", "Bearer #{AuthorizationWorker.token}"}
      ])
    :ok
  end
end
