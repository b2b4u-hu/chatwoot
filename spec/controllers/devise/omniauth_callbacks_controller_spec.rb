require 'rails_helper'

RSpec.describe 'DeviseOverrides::OmniauthCallbacksController', type: :request do
  let(:account_builder) { double }
  let(:user_double) { object_double(:user) }

  def set_omniauth_config(for_email = 'test@example.com')
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: 'google',
      uid: '123545',
      info: {
        name: 'test',
        email: for_email
      }
    )
  end

  describe '#omniauth_sucess' do
    it 'allows signup' do
      set_omniauth_config('test_not_preset@example.com')
      allow(AccountBuilder).to receive(:new).and_return(account_builder)
      allow(account_builder).to receive(:perform).and_return(user_double)

      get '/omniauth/google_oauth2/callback'

      # expect a 302 redirect to auth/google_oauth2/callback
      expect(response).to redirect_to('http://www.example.com/auth/google_oauth2/callback')
      follow_redirect!

      expect(AccountBuilder).to have_received(:new).with({
                                                           account_name: 'example',
                                                           user_full_name: 'test',
                                                           email: 'test_not_preset@example.com',
                                                           locale: I18n.locale,
                                                           confirmed: nil
                                                         })
    end

    it 'blocks personal accounts signup' do
      set_omniauth_config('personal@gmail.com')
      get '/omniauth/google_oauth2/callback'

      # expect a 302 redirect to auth/google_oauth2/callback
      expect(response).to redirect_to('http://www.example.com/auth/google_oauth2/callback')
      follow_redirect!

      # expect a 302 redirect to app/login with error disallowing personal accounts
      expect(response).to redirect_to(%r{/app/login\?error=business-account-only$})
    end

    it 'allows login' do
      create(:user, email: 'test@example.com')
      set_omniauth_config('test@example.com')

      get '/omniauth/google_oauth2/callback'
      # expect a 302 redirect to auth/google_oauth2/callback
      expect(response).to redirect_to('http://www.example.com/auth/google_oauth2/callback')

      follow_redirect!
      expect(response).to redirect_to(%r{/app/login\?email=.+&sso_auth_token=.+$})

      # expect app/login page to respond with 200 and render
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    # from a line coverage point of view this may seem redundant
    # but to ensure that the logic allows for existing users even if they have a gmail account
    # we need to test this explicitly
    it 'allows personal account login' do
      create(:user, email: 'personal-existing@gmail.com')
      set_omniauth_config('personal-existing@gmail.com')

      get '/omniauth/google_oauth2/callback'
      # expect a 302 redirect to auth/google_oauth2/callback
      expect(response).to redirect_to('http://www.example.com/auth/google_oauth2/callback')

      follow_redirect!
      expect(response).to redirect_to(%r{/app/login\?email=.+&sso_auth_token=.+$})

      # expect app/login page to respond with 200 and render
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end