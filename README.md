# Beroon

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Docker

Copy the sample environment file and set real secrets:

```bash
cp .env.example .env
# edit .env and replace SECRET_KEY_BASE, OTP_SECRET, POSTGRES_PASSWORD
```

Generate a Phoenix secret if Elixir is installed locally:

```bash
mix phx.gen.secret
```

Build and run the app with Postgres:

```bash
docker compose up --build -d
```

The app will run on:

```text
http://localhost:4000
```

Migrations run automatically on container startup. Set `RUN_MIGRATIONS=false` in `.env` if you want to run them manually.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
