class Alchemy::PagesController < ApplicationController
  
  layout 'pages'
  
  before_filter :set_language_from_client, :only => [:show, :sitemap]
  before_filter :set_translation, :except => [:show, :preview]
  before_filter :get_page_from_urlname, :only => [:show, :sitemap]
  before_filter :get_page_from_id, :only => [:publish, :unlock, :preview, :edit, :update, :move, :fold, :destroy]
  
  filter_access_to [:show, :unlock, :publish, :preview, :edit, :edit_content, :update, :move, :destroy], :attribute_check => true
  filter_access_to [:index, :systempages, :new, :switch_language, :create_language, :create, :fold], :attribute_check => false
  
  caches_action(
    :show,
    :layout => false,
    :cache_path => Proc.new { |c| c.multi_language? ? "#{c.session[:language]}/#{c.params[:urlname]}" : "#{c.params[:urlname]}" },
    :if => Proc.new { |c| 
      if WaConfigure.parameter(:cache_wa_pages)
        page = WaPage.find_by_urlname_and_language_and_public(
          c.params[:urlname],
          Alchemy::Controller.current_language,
          true,
          :select => 'page_layout, language, urlname'
        )
        if page
          pagelayout = WaPageLayout.get(page.page_layout)
          pagelayout['cache'].nil? || pagelayout['cache']
        end
      else
        false
      end
    }
  )
  cache_sweeper :wa_pages_sweeper, :if => Proc.new { |c| WaConfigure.parameter(:cache_wa_pages) }
  
  def index
    @wa_page_root = WaPage.find(
      :first,
      :include => [:children],
      :conditions => {:language_root_for => session[:language]}
    )
    if @wa_page_root.nil?
      create_new_rootpage
      flash[:notice] = _("WaAdmin|new rootpage created")
    end
    render :layout => 'admin'
  end
  
  def fold
    # @wa_page is fetched via before filter
    @wa_page.fold(current_user.id, !@wa_page.folded?(current_user.id))
    @wa_page.save
    render :nothing => true
  end
  
  def systempages
    @system_root = WaPage.systemroot.first
    render :layout => 'admin'
  end
  
  def new
    @parent_id = params[:parent_id]
    @wa_page = WaPage.new
    render :layout => false
  end
  
  def create
    begin
      parent = WaPage.find(params[:wa_page][:parent_id])
      page_layout = WaPageLayout.get(params[:wa_page][:page_layout])
      params[:wa_page][:created_by] = current_user.id
      params[:wa_page][:updated_by] = current_user.id
      params[:wa_page][:language] = parent.language
      params[:wa_page][:systempage] = ((page_layout["systempage"] == true) rescue false)
      page = WaPage.create(params[:wa_page])
      if page.valid?
        page.move_to_child_of parent
      end
      render_errors_or_redirect(page, wa_pages_path, _("page '%{name}' created.") % {:name => page.name})
    rescue
      log_error($!)
    end
  end
  
  def show
    # @wa_page is fetched via before filter
    # rendering page and querying for search results if any query is present
    if configuration(:ferret) && !params[:query].blank?
      perform_search
    end
  end
  
  def preview
    # fetching page via before filter
  end
  
  def edit
    # fetching page via before filter
    render :layout => false
  end
  
  def update
    # fetching page via before filter
    params[:wa_page][:updated_by] = current_user.id
    @wa_page.update_attributes(params[:wa_page])
    render_errors_or_redirect(@wa_page, request.referer, _("Page %{name} saved") % {:name => @wa_page.name})
  end
  
  def destroy
    # fetching page via before filter
    name = @wa_page.name
    if @wa_page.destroy
      render :update do |page|
        page.replace_html(
          "wa_sitemap",
          :partial => 'wa_page',
          :object => WaPage.language_root(session[:language])
        )
        WaNotice.show_via_ajax(page, _("Page %{name} deleted") % {:name => name})
      end
    end
  end
  
  # Leaves the page editing mode and unlocks the page for other users
  def unlock
    # fetching page via before filter
    @wa_page.unlock
    flash[:notice] = _("unlocked_page_%{name}") % {:name => @wa_page.name}
    if params[:redirect_to].blank?
      redirect_to wa_pages_path
    else
      redirect_to(params[:redirect_to])
    end
  end
  
  # Sweeps the page cache
  def publish
    # fetching page via before filter
    @wa_page.save
    flash[:notice] = _("page_published") % {:name => @wa_page.name}
    redirect_back_or_to_default(wa_pages_path)
  end
  
  def move
    # fetching page via before filter
    @wa_page_root = WaPage.language_root(session[:language])
    my_position = @wa_page.self_and_siblings.index(@wa_page)
    case params[:direction]
    when 'up'
      then
      @wa_page.move_to_left_of @wa_page.self_and_siblings[my_position - 1]
    when 'down'
      then 
      @wa_page.move_to_right_of @wa_page.self_and_siblings[my_position + 1]
    when 'left'
      then
      @wa_page.move_to_right_of @wa_page.parent
    when 'right'
      @wa_page.move_to_child_of @wa_page.self_and_siblings[my_position - 1]
    end
    # We have to save the page for triggering the cache_sweeper, because betternestedset uses transactions.
    # And the sweeper does not get triggered by transactions.
    @wa_page.save
  end
  
  def edit_content
    @wa_page = WaPage.find(
      params[:id],
      :include => {
        :wa_molecules => :wa_atoms
      }
    )
    @systempage = !params[:systempage].blank? && params[:systempage] == 'true'
    @created_by = User.find(@wa_page.created_by).login rescue ""
    @updated_by = User.find(@wa_page.updated_by).login rescue ""
    if @wa_page.locked? && @wa_page.locker != current_user
      flash[:notice] = _("This page is locked by %{name}") % {:name => (@wa_page.locker.name rescue _('unknown'))}
      redirect_to wa_pages_path
    else
      @wa_page.lock(current_user)
      render :layout => 'admin'
    end
  end
  
  def create_language
    created_languages = WaPage.language_roots.collect(&:language)
    all_languages = WaConfigure.parameter(:languages).collect{ |l| [l[:language], l[:language_code]] }
    @languages = all_languages.select{ |lang| created_languages.include?(lang[1]) }
    lang = configuration(:languages).detect { |l| l[:language_code] == params[:language_code] }
    @language = [
      lang[:language],
      params[:language_code]
    ]
    render :layout => false
  end
  
  def copy_language
    set_language(params[:languages][:new_lang])
    begin
      # copy language root from old to new language
      original_language_root = WaPage.find_by_language_root_for(params[:languages][:old_lang])
      new_language_root = WaPage.copy(
        original_language_root,
        :language => params[:languages][:new_lang],
        :language_root_for => params[:languages][:new_lang],
        :public => false
      )
      new_language_root.move_to_child_of WaPage.root
      copy_child_pages(original_language_root, new_language_root)
      flash[:notice] = _('language_pages_copied')
    rescue
      log_error($!)
      flash[:notice] = _('language_pages_could_not_be_copied')
    end
    redirect_to :action => :index
  end
  
  # renders a Google conform sitemap in xml
  def sitemap
    @wa_pages = WaPage.find_all_by_sitemap_and_public(true, true)
    respond_to do |format|
      format.xml { render :layout => "sitemap" }
    end
  end
  
  def sort
    #
  end
  
  def switch_language
    if WaPage.find_by_language_root_for(params[:language], :select => 'id').nil?
      title = _('create_new_language')
      render :update do |page|
        page << %(wa_overlay_window(
          '#{url_for(
            :controller => :wa_pages,
            :action => :create_language,
            :language_code => params[:language]
          )}',
          '#{title}',
          255,
          200,
          false,
          'true',
          false
        ))
      end
    else
      set_language(params[:language])
      if request.xhr?
        render :update do |page|
          page.redirect_to wa_pages_url
        end
      else
        redirect_to wa_pages_url
      end
    end
  end
  
private
  
  def copy_child_pages(source_page, new_page)
    source_page.children.each do |child_page|
      new_child = WaPage.copy(child_page, :language => new_page.language, :public => false)
      new_child.move_to_child_of new_page
      unless child_page.children.blank?
        copy_child_pages(child_page, new_child)
      end
    end
  end
  
  def create_new_rootpage
    lang = configuration(:languages).detect{ |l| l[:language_code] == session[:language] }
    @wa_page_root = WaPage.create(
      :name => lang[:frontpage_name],
      :page_layout => lang[:page_layout],
      :language => lang[:language_code],
      :language_root_for => lang[:language_code],
      :public => false,
      :visible => true
    )
    @wa_page_root.move_to_child_of WaPage.root
  end
  
  def get_page_from_urlname
    if params[:urlname].blank?
      @wa_page = WaPage.find_by_language_root_for(session[:language])
    else
      @wa_page = WaPage.find_by_urlname_and_language(params[:urlname], session[:language])
    end
    if @wa_page.blank?
      render(:file => "#{RAILS_ROOT}/public/404.html", :status => 404)
    elsif @wa_page.has_controller?
      redirect_to(@wa_page.controller_and_action)
    elsif configuration(:redirect_to_public_child) && !@wa_page.public?
      redirect_to_public_child
    elsif multi_language? && params[:lang].blank?
      redirect_to show_page_with_language_path(:urlname => @wa_page.urlname, :lang => session[:language])
    end
  end
  
  def find_first_public(page)
    if(page.public == true)
      return page
    end
    page.children.each do |child|
      result = find_first_public(child)
      if(result!=nil)
        return result
      end
    end
    return nil
  end
  
  def redirect_to_public_child
    @wa_page = find_first_public(@wa_page)
    if @wa_page
      redirect_page
    else
      render :file => "#{Rails.root}/public/404.html", :status => 404
    end
  end
  
  def redirect_page
    get_additional_params
    redirect_to(
      send(
        "show_page_#{multi_language? ? 'with_language_' : nil }path".to_sym, {
          :lang => (multi_language? ? @wa_page.language : nil),
          :urlname => @wa_page.urlname
        }.merge(@additional_params)
      ),
      :status => 301
    )
  end
  
  def get_additional_params
    @additional_params = params.clone.delete_if do |key, value|
      ["action", "controller", "urlname", "lang"].include?(key)
    end
  end
  
  def get_page_from_id
    @wa_page = WaPage.find(params[:id])
  end
  
  def perform_search
    @rtf_search_results = WaAtomRtf.find_by_contents(
      "*" + params[:query] + "*",
      {:limit => :all},
      {:conditions => "public = 1"}
    )
    @text_search_results = WaAtomText.find_by_contents(
      "*" + params[:query] + "*",
      {:limit => :all},
      {:conditions => "public = 1"}
    )
  end

end