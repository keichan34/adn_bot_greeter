defmodule AdnBotGreeter do
  use Application

  def start(_type, _args) do
    AdnBotGreeter.Supervisor.start_link
  end

  def get_env(key) do
    Application.get_env __MODULE__, key
  end
end
