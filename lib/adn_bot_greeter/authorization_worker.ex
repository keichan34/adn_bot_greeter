defmodule AdnBotGreeter.AuthorizationWorker do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def token do
    {:ok, tok} = GenServer.call(__MODULE__, :token)
    tok
  end

  def init(_) do
    {:ok, %{token: nil}}
  end

  def handle_call(:token, _from, state) do
    state = refresh_credentials(state)
    {:reply, {:ok, state[:token]}, state}
  end

  defp refresh_credentials(%{token: nil} = state) do
    {:ok, %HTTPoison.Response{body: body, status_code: 200}} =
      HTTPoison.post(
        "https://account.app.net/oauth/access_token",
        URI.encode_query(%{
          "client_id" => AdnBotGreeter.get_env(:adn_client_id),
          "client_secret" => AdnBotGreeter.get_env(:adn_client_secret),
          "grant_type" => "client_credentials"
        }),
        [
          {"User-Agent", "adnbotgreeter-0"},
          {"Content-Type", "application/x-www-form-urlencoded"}
        ]
      )

    decoded = Poison.Parser.parse!(body)

    %{state | token: decoded["access_token"]}
  end

  defp refresh_credentials(state), do: state
end
