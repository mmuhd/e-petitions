require 'rails_helper'

RSpec.describe 'token', type: :request do
  let(:user_attributes) do
    {
      first_name: "System",
      last_name: "Administrator",
      email: "admin@petition.parliament.uk",
      password: "L3tme1n!",
      password_confirmation: "L3tme1n!"
    }
  end

  let(:login_params) do
    { email: "admin@petition.parliament.uk", password: "L3tme1n!" }
  end

  let(:encrypted_csrf_token) do
    one_time_pad.bytes.zip(real_csrf_token.bytes).map { |(c1,c2)| c1 ^ c2 }.pack('c*')
  end

  let(:real_csrf_token) { Base64.strict_decode64(session[:_csrf_token]) }
  let(:one_time_pad) { SecureRandom.random_bytes(32) }
  let(:masked_token) { one_time_pad + encrypted_csrf_token }
  let(:authenticity_token) { Base64.strict_encode64(masked_token) }

  before do
    FactoryBot.create(:sysadmin_user, user_attributes)

    host! "moderate.petition.parliament.uk"
    https!

    get "/admin/login"
  end

  context "when a new session is created" do
    it "resets the csrf token" do
      expect {
        post "/admin/user_sessions", admin_user_session: login_params, authenticity_token: authenticity_token
      }.to change {
        session[:_csrf_token]
      }
    end
  end

  context "when a session is destroyed" do
    it "resets the csrf token" do
      expect {
        get "/admin/logout"
      }.to change {
        session[:_csrf_token]
      }
    end
  end

  context "when a session is stale" do
    it "resets the csrf token" do
      Site.instance.update(login_timeout: 600)

      travel_to 5.minutes.ago do
        post "/admin/user_sessions", admin_user_session: login_params, authenticity_token: authenticity_token
        expect(response).to redirect_to("/admin")
      end

      get "/admin"
      expect(response).to be_successful

      travel_to 15.minutes.from_now do
        expect {
          get "/admin"
          expect(response).to redirect_to("/admin/login")
        }.to change {
          session[:_csrf_token]
        }
      end

      Site.instance.update(login_timeout: 1800)

      travel_to 15.minutes.from_now do
        get "/admin"
        expect(response).to redirect_to("/admin/login")
      end
    end
  end
end
