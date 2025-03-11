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
      get :download_excel_file2
    end
  end

  resources :units do
    member do
      get :combined_pdf
      get :combined_pdf2
    end
  end 

  get '/compare_units', to: 'units#compare_units', as: 'compare_units'
  get '/compare_units/download_excel', to: 'units#download_comparison_excel', as: 'download_comparison_excel'
  get '/compare_units/download_pdf', to: 'units#download_comparison_pdf', as: 'download_comparison_pdf'


  match '/generate_file', to: 'tests#generate_file', via: [:get, :post]

  resources :tests, only: [:index, :create] do
    collection do
      get 'run_test_page'
      get 'new_test'
      post 'check_radios'
      post 'test_mode'
      get 'run_ble_test'
      post 'run_ble_test_action'
    end
  end

end
