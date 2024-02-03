class ItemsController < ApplicationController
  layout 'centered_layout', only: [:new, :edit]

  def show
    @item = Item.find(params[:id])
    @article = @recording = @word_list = @item.itemable
  end

  def create
    @course = current_user.courses.find(item_params[:course_id])
    authorize(@course)
    @item = @course.items.build(item_params)

    if @item.save!
      respond_to do |format|
        format.html { redirect_to @course }
      end
    else
      render :new
    end
  end

  def new
    @itemable = params[:itemable_type].constantize.find(params[:itemable_id])
    @item = Item.new(itemable_id: @itemable_id, itemable_type: @itemable_type)
    authorize @item
    @courses = current_user.courses.all # Assuming the user can choose from all courses
  end

  def edit
    @item = Item.find(params[:id])
    authorize(@item)
  end

  def update
    @item = Item.find(params[:id])
    authorize(@item)

    if @item.update(item_params)
      redirect_to @item.course
    else
      render :edit
    end
  end

  private

  def item_params
    params.require(:item).permit(:name, :description, :course_id, :itemable_id, :itemable_type) # Add other fields as necessary
  end
end
