# Connects deliberate Index and Custom Collection gestures to Collection's
# domain-owned lifecycle operations.
class CollectionsController < ApplicationController
  include JournalReading

  # One reader-facing refusal for an unavailable Collection transition.
  REFUSAL_ALERT = "That Collection can't do that.".freeze
  # The exact-name gesture deliberately reveals no distinction among misses.
  LOCATE_ALERT = "No Collection with that exact Topic.".freeze

  before_action :set_collection, except: %i[index create locate]
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from Collection::LifecycleError, with: :refuse_collection_change

  # Shows only explicitly registered Topics in their manual order.
  def index
    prepare_index
  end

  # Creates one unindexed Collection and opens its canonical page.
  def create
    @new_collection = user_collections.new(collection_params)
    if @new_collection.save
      redirect_to collection_path(@new_collection)
    else
      @new_collection_name = params.dig(:collection, :name)
      @new_collection_open = true
      prepare_index
      render :index, status: :unprocessable_entity
    end
  end

  # Opens a known Collection by exact Topic without exposing candidates.
  def locate
    collection = user_collections.kept.with_exact_topic(params[:topic]).first
    return redirect_to collection_path(collection) if collection

    flash.now[:alert] = LOCATE_ALERT
    @locate_open = true
    prepare_index
    render :index, status: :unprocessable_entity
  end

  # Shows one kept Collection and its resident root trees.
  def show
    prepare_collection_page
  end

  # Renames the Collection without changing its stable URL or Index order.
  def update
    if @collection.update(collection_params)
      redirect_to collection_path(@collection)
    else
      render_collection_validation
    end
  end

  # Adds a nonempty unindexed Collection at the end of the manual Index.
  def register
    @collection.register!
    redirect_to collection_path(@collection)
  end

  # Removes an indexed Collection from the Index without deleting its page.
  def unindex
    @collection.unindex!
    redirect_to collection_path(@collection)
  end

  # Soft-deletes a never-used Collection and returns to the Index.
  def destroy
    @collection.soft_delete_if_unused!
    redirect_to journal_index_path, notice: "Collection deleted."
  end

  private

  def set_collection
    @collection = user_collections.kept.find(params[:id])
  end

  def prepare_index
    @collections = user_collections.in_index_order
    @new_collection ||= user_collections.new
  end

  def prepare_collection_page
    @entries = user_entries.collection_page(@collection.id)
  end

  def collection_params
    params.fetch(:collection, {}).permit(:name)
  end

  def render_collection_validation
    @form_errors = @collection.errors.full_messages
    @collection.reload
    @manage_open = true
    prepare_collection_page
    render :show, status: :unprocessable_entity
  end

  def refuse_collection_change
    redirect_to collection_path(@collection), alert: REFUSAL_ALERT
  end

  def render_not_found
    render :not_found, status: :not_found
  end
end
