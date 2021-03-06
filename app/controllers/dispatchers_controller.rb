# Dispatcher controller
class DispatchersController < ApplicationController
  before_action :authenticate_request!, only: [:index_driver]

  def index
    # render json: { 'logged_in' => true }
  end

  def index_driver
    if @current_user.try(:instance_of?, Driver)
      return render json: { 'error' => 'You are not allowed to see a driver list' }, status: 403
    end
    render json: Driver.all
  end

  # for auth dispatcher. Instead of new controller
  def create
    dispatcher = Dispatcher.find_by(email: params[:email])
    if dispatcher.try(:valid_password?, params[:password])
      render json: payload(dispatcher)
    else
      status = dispatcher ? 'Invalid password' : 'Invalid email'
      render json: { errors: [status] }, status: :unprocessable_entity
    end
  end

  private

  def payload(user)
    return nil unless user && user.id
    {
      auth_token: JsonWebToken.encode(user_id: user.id, type: 'Dispatcher'),
      dispatcher: { id: user.id, email: user.email, type: 'Dispatcher' }
    }
  end
end
