Contacts::Application.routes.draw do

  namespace 'v0' do
    resources :contacts do
      member do
        get  :similar
        post  :similar
        post :link
      end
      collection do
        get  :by_kshema_id, to: 'contacts#show_by_kshema_id'
        get  :by_slug, to: 'contacts#show_by_slug'
        post :search, to: 'contacts#index'
        get :search_for_select
        delete :destroy_multiple
      end
      resource :avatar, :only => [:create, :destroy]
      resources :history_entries
    end
    scope 'contacts' do
      resource :calculate, only: [] do
        collection do
          get 'average_age', to: 'calculates#average_age'
          post 'average_age', to: 'calculates#average_age'
        end
      end
    end
    resources :mailchimp_synchronizers, only: [:create,:update,:show,:destroy] do
      member do
        post :synchronize
      end
      collection do
        get :get_scope
      end
    end
    resources :mailchimp_segments
    resources :imports do
      member do
        get 'failed_rows'
      end
    end
    resources :contact_attributes do
      collection do
        get :custom_keys
        post :create_from_kshema, to: 'contact_attributes#create_from_kshema'
        put :update_neighborhood_from_kshema, to: 'contact_attributes#update_neighborhood_from_kshema'
      end
    end
    resources :attachments
    resources :tags
    resource :avatar, :only => [:create, :destroy]
    scope "/accounts/:account_name" do
      resources :tags do
        collection do
          post 'batch_add'
        end
      end
      resources :attachments
      resources :contacts do
        collection do
          get  :by_kshema_id, to: 'contacts#show_by_kshema_id'
        end
        resources :contact_attributes
        resources :tags
      end
      scope 'contacts' do
        resource :calculate, only: [] do
          collection do
            get 'average_age', to: 'calculates#average_age'
            post 'average_age', to: 'calculates#average_age'
          end
        end
      end
    end
    resources :merges do
      member do
        put 'confirm'
      end
    end
  end

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
