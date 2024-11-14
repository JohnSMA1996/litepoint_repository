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

  resources :units do
    member do
      get :combined_pdf
    end
  end 

  get '/compare_units', to: 'units#compare_units', as: 'compare_units'

  match '/generate_file', to: 'tests#generate_file', via: [:get, :post]

  resources :tests, only: [:index, :create] do
    collection do
      get 'run_test_page'
      get 'new_test'
      post 'check_radios'
      post 'test_mode'
    end
  end

end
