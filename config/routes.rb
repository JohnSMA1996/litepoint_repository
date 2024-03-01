Rails.application.routes.draw do
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

  get '/compare_units', to: 'units#compare_units', as: 'compare_units'

  match '/generate_file', to: 'tests#generate_file', via: [:get, :post]

  resources :tests, only: [:index, :create]

  post 'tests/run_script', to: 'tests#run_script', as: 'run_script'

  resources :tests do
    collection do
      get 'run_test_page'
      get 'new_test'
      post 'check_radios'
    end
  end

end
