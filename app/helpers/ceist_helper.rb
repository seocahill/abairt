module CeistHelper
  def ceist_color(ceist)
    if ceist.ceist?
      "green"
    else
      "yellow"
    end
  end
end
