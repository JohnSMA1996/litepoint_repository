Rails.application.routes.draw do
  
  # get 'home/index'
  root 'home#index'
  get 'home/about'
  

  resources :units do
    member do
      get :download
    end
  end
  
  resources :units do
    member do
      get :download_excel
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
