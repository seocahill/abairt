# frozen_string_literal: true

Doorkeeper.configure do
  # Use ActiveRecord for token/grant/application storage.
  orm :active_record

  # Check whether the resource owner is authenticated. MCP clients such as Claude web
  # rely on the existing session-based login. If the user is not signed in we stash the
  # OAuth request and bounce them through the magic-link login, returning them to the
  # authorization page afterwards (see SessionsController).
  resource_owner_authenticator do
    current_resource_owner = User.find_by(id: session[:user_id], confirmed: true)

    unless current_resource_owner
      session[:user_return_to] = request.fullpath
      redirect_to(main_app.login_path, alert: "Caithfidh tú a bheith sínithe isteach!")
    end

    current_resource_owner
  end

  # Only admins may manage OAuth applications through Doorkeeper's built-in UI.
  admin_authenticator do
    user = User.find_by(id: session[:user_id])
    if user&.admin?
      user
    else
      redirect_to(main_app.root_path, alert: "Ní féidir leat an leathanach sin a rochtain.")
    end
  end

  # Access tokens are short-lived; Claude refreshes them using the refresh token.
  access_token_expires_in 2.hours
  use_refresh_token

  # Reuse a still-valid access token instead of minting a new one on every exchange.
  reuse_access_token

  # Scopes advertised in the authorization-server metadata.
  default_scopes :mcp
  optional_scopes :read, :write

  # Only the authorization code grant is used by MCP clients. Public clients (Claude web
  # registers as one via Dynamic Client Registration) authenticate with PKCE and therefore
  # do not present a client secret at the token endpoint.
  grant_flows %w[authorization_code]
end
