# frozen_string_literal: true

class AdminEmailsController < ApplicationController
  before_action :ensure_admin
  before_action :set_email, only: [:show, :edit, :update, :send_email, :send_to_self]

  def index
    authorize User
    @emails = Email.order(created_at: :desc)
  end

  def show
    authorize User
  end

  def new
    authorize User
    @email = Email.new
  end

  def create
    authorize User
    @email = Email.new(email_params)
    @email.sent_by = current_user

    if @email.save
      redirect_to admin_email_path(@email), notice: 'Ríomhphost cruthaithe. Féach air agus seol é.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize User
  end

  def update
    authorize User
    if @email.update(email_params)
      redirect_to admin_email_path(@email), notice: 'Ríomhphost nuashonraithe.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def send_email
    authorize User
    if @email.sent?
      redirect_to admin_email_path(@email), alert: 'Ríomhphost seolta cheana féin.'
      return
    end

    @email.update!(sent_at: Time.current)
    BroadcastEmailJob.perform_later(@email.id)

    eligible_count = User.active
                          .where(confirmed: true)
                          .where.not(role: [:speaker, :ai, :place, :temporary])
                          .where.not("email LIKE ?", "%@abairt.com")
                          .count

    redirect_to admin_email_path(@email), notice: "Ríomhphost á sheoladh chuig #{eligible_count} úsáideoirí sa chúlra."
  end

  def send_to_self
    authorize User
    BroadcastEmailJob.perform_later(@email.id, current_user.id)

    redirect_to admin_email_path(@email), notice: "Ríomhphost á sheoladh chugat féin mar thástáil."
  end

  private

  def set_email
    @email = Email.find(params[:id])
  end

  def email_params
    params.require(:email).permit(:subject, :rich_content)
  end

  def ensure_admin
    user = User.find_by(id: session[:user_id])
    unless user&.admin?
      redirect_to root_path, alert: 'Ní féidir leat an leathanach sin a rochtain.'
    end
  end
end