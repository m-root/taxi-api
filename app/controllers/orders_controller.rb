# class for orders management
class OrdersController < ApplicationController
  before_action :check_client_params, only: [:create]
  before_action :authenticate_request!, only: [:index, :show, :update, :cancel, :apply, :complete, :cancel_request]

  def index
    user = @current_user.class.name.downcase.concat('_id')
    render json: { user => @current_user.id, 'orders' => Order.all }
  end

  # here i should create order from params
  def create
    order = Order.new(order_params(@client.id))
    if order.save
      render json: { 'result' => order }
    else
      render json: { 'error' => order.errors }, status: :unprocessable_entity
    end
  end

  def show
    order = Order.find(params[:id])
    client_phone = { 'client_phone' => Client.find(order.client_id).phone }
    render json: { 'order' => order.attributes.merge(client_phone) }
  end

  def update
    if @current_user.try(:instance_of?, Driver)
      return render json: { 'error' => 'You are not allowed to change an order' }, status: 403
    end
    query = Order.update(params[:id], update_order_params)
    return render json: { 'error' => query.errors }, status: 422 unless query.errors.blank?
    render json: { 'current_order' => query.attributes }
  end

  def apply
    return render json: { 'error' => 'You are not a driver' }, status: 403 unless @current_user.instance_of? Driver
    order = Order.find(params[:id])
    order.driver_id = @current_user.id
    order.state = 'active'
    @current_user.update(status: 'active')
    order.save
    send_email_to_client_apply(order.id, order.client_id)
    render json: { 'current_order' => order }
  end

  def complete
    return render json: { 'error' => 'You are not a driver' }, status: 403 unless @current_user.instance_of? Driver
    order = Order.find(params[:id])
    order.driver_id = @current_user.id
    order.state = 'completed'
    @current_user.update(status: 'not active')
    order.save
    send_email_to_client_complete(order.id, order.client_id)
    render json: { 'current_order' => order }
  end

  def cancel
    if @current_user.instance_of? Driver
      return render json: { 'error' => 'You are not allowed to cancel an order' }, status: 403
    end
    order = Order.find(params[:id])
    order.state = 'canceled'
    Driver.update(order.driver_id, status: 'not active')
    order.save
    send_email_to_client_cancel(order.id, order.client_id)
    render json: { 'current_order' => order }
  end

  def cancel_request
    return render json: { 'error' => 'You are not a driver' }, status: 403 unless @current_user.instance_of? Driver
    cancel_comment = Order.update(params[:id], update_order_params_cancel)
    return render json: { 'error' => cancel_comment.errors }, status: 422 unless cancel_comment.errors.blank?
    render json: { 'current_order' => cancel_comment.attributes }
  end

  private

  def send_email_to_client_apply(order_id, client_id)
    client_email = Client.find(client_id).email
    ClientMailer.welcome_email(order_id, client_email).deliver_now if client_email
  end

  def send_email_to_client_complete(order_id, client_id)
    client_email = Client.find(client_id).email
    ClientMailer.complete_email(order_id, client_email).deliver_now if client_email
  end

  def send_email_to_client_cancel(order_id, client_id)
    client_email = Client.find(client_id).email
    ClientMailer.cancel_email(order_id, client_email).deliver_now if client_email
  end

  def check_client_params
    @client = Client.current_client(client_params) # id of client in hash
    render json: { 'error' => @client.errors }, status: :unprocessable_entity unless @client.errors.empty?
  end

  def update_order_params
    params.require(:order).permit(:from, :to, :comment, :state, :client_id, :driver_id, :price)
  end

  def update_order_params_cancel
    params.require(:order).permit(:cancel_comment, :cancel_request)
  end

  def client_params
    params.require(:client).permit(:email, :phone)
  end

  def order_params(client_id)
    parameters = params.require(:order).permit(:from, :to, :comment)
    parameters['client_id'] = client_id
    parameters
  end
end
