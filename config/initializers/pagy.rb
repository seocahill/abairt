require 'pagy/extras/overflow'
require 'pagy/extras/array'

# default :empty_page (other options :last_page and :exception )
Pagy::DEFAULT[:overflow] = :last_page
