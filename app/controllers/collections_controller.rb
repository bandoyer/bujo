# Connects the complete Index and Custom Collection gestures to their domain.
class CollectionsController < ApplicationController
  include JournalReading

  # One reader-facing refusal for guarded Collection deletion.
  REFUSAL_ALERT = "That Collection can't do that.".freeze

  before_action :set_collection, except: %i[index create]
  rescue_from ActiveRecord::RecordNotFound, with: :render_collection_not_found
  rescue_from Collection::LifecycleError, with: :refuse_collection_change

  # Shows every kept Topic in permanent append order.
  def index
    prepare_index
  end

  # Atomically creates and indexes one Collection, then opens its stable page.
  def create
    @new_collection = Collection.create_for(
      user: Current.user,
      topic: collection_params[:name]
    )
    if @new_collection.persisted?
      redirect_to collection_path(@new_collection), notice: "Collection created."
    else
      render_index_validation
    end
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
    # A refused create has already put its rejected record here, and Rails
    # marks the field that record rejected; a blank one would render the form
    # as though nothing had been refused. Only an untouched Index builds one.
    @new_collection ||= user_collections.new
  end

  def prepare_collection_page
    @entries = user_entries.collection_page(@collection.id)
  end

  def collection_params
    params.fetch(:collection, {}).permit(:name)
  end

  def render_index_validation
    # Keep the raw submitted Topic so a refusal does not display a stripped
    # value, and keep the rejected record so Rails can mark the field.
    @form_errors = @new_collection.errors.full_messages
    @new_collection_name = params.dig(:collection, :name)
    @new_collection_open = true
    prepare_index
    render :index, status: :unprocessable_entity
  end

  def render_collection_validation
    # Read the errors off the rejected record, then restore it: the page's
    # title and Index state must show what is persisted, not what was typed.
    @form_errors = @collection.errors.full_messages
    @collection.reload
    @manage_open = true
    prepare_collection_page
    render :show, status: :unprocessable_entity
  end

  def refuse_collection_change
    redirect_to collection_path(@collection), alert: REFUSAL_ALERT
  end
end
