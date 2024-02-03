# app/controllers/courses_controller.rb
class CoursesController < ApplicationController
  before_action :set_course, only: [:show, :edit, :update, :destroy]
  layout "centered_layout", only: [:new, :edit]
  # GET /courses
  def index
    @courses = Course.all
    authorize @courses
  end

  # GET /courses/1
  def show
    authorize @course
  end

  # GET /courses/new
  def new
    @course = Course.new
    authorize @course
  end

  # GET /courses/1/edit
  def edit
    authorize @course
  end

  # POST /courses
  def create
    @course = Course.new(course_params)
    authorize @course

    if @course.save
      redirect_to @course, notice: 'Course was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /courses/1
  def update
    authorize @course
    if @course.update(course_params)
      redirect_to @course, notice: 'Course was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /courses/1
  def destroy
    authorize @course
    @course.destroy
    redirect_to courses_url, notice: 'Course was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_course
      @course = Course.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def course_params
      params.require(:course).permit(:name, :description, :user_id)
    end
end
