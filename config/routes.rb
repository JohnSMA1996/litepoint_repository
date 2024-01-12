Rails.application.routes.draw do
  
  # get 'home/index'
  root 'home#index'
  get 'home/about'
  
  get 'search', to:"units#search"

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

  match '/generate_file', to: 'tests#generate_file', via: [:get, :post]

  resources :tests, only: [:index, :create]

  resources :tests do
    collection do
      get 'folder_contents'
      get 'new_test'
    end
  end

end
