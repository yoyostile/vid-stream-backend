class StreamsController < ApplicationController
  def index
    @streams = Stream.all_active
  end

  def create
  end
end
