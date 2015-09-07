defmodule AdnBotGreeter.Supervisor do
  use Supervisor

  alias AdnBotGreeter.Nice
  alias AdnBotGreeter.AuthorizationWorker
  alias AdnBotGreeter.GlobalStream
  alias AdnBotGreeter.GlobalProcessor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      worker(AuthorizationWorker, []),
      worker(Nice, []),
      worker(GlobalStream, []),
      worker(GlobalProcessor, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
