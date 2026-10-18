# frozen_string_literal: true

MinecraftServer::Engine.routes.draw do
  get "/" => "pages#index"
  get "/servers.json" => "servers#index"
  get "/mine.json" => "servers#mine"
  post "/servers" => "servers#create"
  put "/servers/:id" => "servers#update"
  delete "/servers/:id" => "servers#destroy"
  post "/servers/:id/refresh" => "servers#refresh"
  get "/admin/servers.json" => "admin#index"
  put "/admin/servers/:id" => "admin#update"
  delete "/admin/servers/:id" => "admin#destroy"
  post "/admin/servers/:id/refresh" => "admin#refresh"
end

Discourse::Application.routes.draw do
  mount ::MinecraftServer::Engine, at: "/minecraft-servers"
end