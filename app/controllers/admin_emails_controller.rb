# frozen_string_literal: true

class AdminEmailsController < ApplicationController
  before_action :ensure_admin

  def new
    authorize User
  end

  def create
    authorize User
    
    @subject = params[:subject]
    @message = params[:message]
    
    if @subject.blank? || @message.blank?
      redirect_to new_admin_email_path, alert: 'Caithfidh ábhar agus teachtaireacht a bheith ann.'
      return
    end

    BroadcastEmailJob.perform_later(@subject, @message)

    redirect_to new_admin_email_path, notice: "Ríomhphost á sheoladh chuig #{User.active.count} úsáideoirí sa chúlra."
  end

  private

  def ensure_admin
    unless current_user&.admin?
      redirect_to root_path, alert: 'Ní féidir leat an leathanach sin a rochtain.'
    end
  end
end