class WordListsController < ApplicationController
  before_action :set_word_list, only: [:show, :edit, :update, :destroy]

  # GET /word_lists
  def index
    @word_lists = WordList.all
  end

  # GET /word_lists/1
  def show
  end

  # GET /word_lists/new
  def new
    @word_list = WordList.new
  end

  # GET /word_lists/1/edit
  def edit
  end

  # POST /word_lists
  def create
    @word_list = WordList.new(word_list_params)

    if @word_list.save
      redirect_to @word_list, notice: 'Word list was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /word_lists/1
  def update
    if @word_list.update(word_list_params)
      redirect_to @word_list, notice: 'Word list was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /word_lists/1
  def destroy
    @word_list.destroy
    redirect_to word_lists_url, notice: 'Word list was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_word_list
      @word_list = WordList.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def word_list_params
      params.require(:word_list).permit(:name, :user_id, :description)
    end
end
