import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :notesclub, Notesclub.Repo,
  username: "general_admin",
  password: "admin",
  hostname: "localhost",
  database: "notesclub_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :notesclub, NotesclubWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "cFPVmqT3iScJcN+jj0TWM+lTxB4diWBC0r8K+vJUYKrobjPFgd82Yo6LCqGrxsAZ",
  server: false

# In test we don't send emails.
config :notesclub, Notesclub.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :notesclub, Oban, testing: :manual

if File.exists?("config/test_secrets.exs") do
  import_config "test_secrets.exs"
end
