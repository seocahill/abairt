class WordListsController < ApplicationController
  before_action :set_word_list, only: [:show, :edit, :update, :destroy]

  # GET /word_lists
  def index
    @new_list = current_user.own_lists.new
    records = WordList.where("id is not null AND starred is not true")

    if params[:search].present?
      records = WordList.where(starred: nil).where("name LIKE ? OR description LIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    @pagy, @word_lists = pagy(records, items: PAGE_SIZE)
  end

  # GET /word_lists/1
  def show
    if (params[:phrase].present? || params[:idiom].present?)
      @vector_search = EntryEmbedding.new
    end

    if params[:phrase].present?
      @results = @vector_search.list_grammatic_forms(params[:phrase]).split("\n")
    end

    if params[:idiom].present?
      @idioms = @vector_search.list_idioms(params[:idiom]).split("\n")
    end
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
    authorize @word_list
  end

  # GET /word_lists/1/edit
  def edit
    authorize @word_list
  end

  # POST /word_lists
  def create
    @word_list = current_user.own_lists.build(word_list_params)
    authorize @word_list

    if @word_list.save
      GenerateWordListJob.perform_later(@word_list) if @word_list.description.present?
      redirect_to @word_list, notice: 'Word list was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /word_lists/1
  def update
    authorize @word_list

    GenerateScriptJob.perform_later(@word_list, params[:generate_script]) if params[:generate_script]

    if params[:phrase]
      @word_list.dictionary_entries.build(word_or_phrase: params[:result], translation: params[:phrase], owner: User.ai.first)
    end

    if @word_list.update(word_list_params)
      redirect_to @word_list, notice: 'Word list was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /word_lists/1
  def destroy
    authorize @word_list
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
      params.require(:word_list).permit(:name, :description, :media)
    end
end
