class WordListsController < ApplicationController
  before_action :set_word_list, only: [:show, :edit, :update, :destroy]
  before_action :authenticate, except: [:show, :index]

  # GET /word_lists
  def index
    records = WordList.where("id is not null AND starred is not true")

    if params[:search].present?
      records = WordList.where(starred: nil).where("name LIKE ? OR description LIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    @pagy, @word_lists = pagy(records, items: PAGE_SIZE)
  end

  # GET /word_lists/1
  def show
    @pagy, @entries = pagy(@word_list.dictionary_entries, items: PAGE_SIZE)
    respond_to do |format|
      format.html
      format.csv { send_data @word_list.to_csv, filename: "#{@word_list.name}.csv" }
      format.json { render json: records }
    end
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
    @word_list = current_user.own_lists.build(word_list_params)

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
      params.permit(:name, :description)
    end
end
