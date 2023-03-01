Rails.application.routes.draw do
  
  # get 'home/index'
  root 'home#index'
  get 'home/about'

  post 'upload_file', to: 'units#upload_file'

  resources :units do
    member do
      get :download
    end
  end
  

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
