module ItemsHelper
  def render_itemable_content(itemable)
        render template: "#{itemable.class.name.underscore.pluralize}/show", locals: { itemable.model_name.element.to_sym => itemable }
  end
end
