class MessagesController < ApplicationController
  before_action :set_message, only: %i[destroy]
  before_action :authenticate_user!, only: %i[create]

  def create
    @message = Message.new(message_params)
    @message.user_id = session_current_user_id
    @temp_message_id = (0...20).map { ("a".."z").to_a[rand(8)] }.join
    authorize @message

    if @message.valid?
      begin
        message_json = create_pusher_payload(@message, @temp_message_id)
        Pusher.trigger(@message.chat_channel.pusher_channels, "message-created", message_json)
      rescue Pusher::Error => e
        logger.info "PUSHER ERROR: #{e.message}"
      end
    end

    if @message.save
      render json: { status: "success", message: { temp_id: @temp_message_id, id: @message.id } }, status: :created
    else
      render json: {
        status: "error",
        message: {
          chat_channel_id: @message.chat_channel_id,
          message: @message.errors.full_messages,
          type: "error"
        }
      }, status: :unauthorized
    end
  end

  def destroy
    authorize @message

    if @message.valid?
      begin
        Pusher.trigger(@message.chat_channel.pusher_channels, "message-deleted", @message.to_json)
      rescue Pusher::Error => e
        logger.info "PUSHER ERROR: #{e.message}"
      end
    end

    if @message.destroy
      render json: { status: "success", message: "Message was deleted" }
    else
      render json: {
        status: "error",
        message: {
          chat_channel_id: @message.chat_channel_id,
          message: @message.errors.full_messages,
          type: "error"
        }
      }, status: :unauthorized
    end
  end

  private

  def create_pusher_payload(new_message, temp_id)
    {
      temp_id: temp_id,
      user_id: new_message.user.id,
      chat_channel_id: new_message.chat_channel.id,
      chat_channel_adjusted_slug: new_message.chat_channel.adjusted_slug(current_user, "sender"),
      username: new_message.user.username,
      profile_image_url: ProfileImage.new(new_message.user).get(90),
      message: new_message.message_html,
      timestamp: Time.current,
      color: new_message.preferred_user_color,
      reception_method: "pushed"
    }.to_json
  end

  def message_params
    params.require(:message).permit(:message_markdown, :user_id, :chat_channel_id)
  end

  def set_message
    logger.info "PUSHER ERROR: #{params[:id]}"
    @message = Message.find(params[:id])
  end

  def user_not_authorized
    respond_to do |format|
      format.json do
        render json: {
          status: "error",
          message: {
            chat_channel_id: message_params[:chat_channel_id],
            message: "You can not do that because you are banned",
            type: "error"
          }
        }, status: :unauthorized
      end
    end
  end
end
