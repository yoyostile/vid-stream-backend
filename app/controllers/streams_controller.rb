class StreamsController < ApplicationController
  def index
    @streams = Stream.all_active
  end

  def show
    @stream = Stream.find_by(public_id: params[:id])
  end

  def create
  end
end
