#
#	constants, defaults as callbacks arity 0
#
constants =
	default_opts: () -> {
		blocks: [{val: "main_page", lab: "данные"},{val: "opts", lab: "опции"}]
		sidebar: false
		showing_block: "main_page"
		version: '__VERSION__'
		search_groups: false
		search_users: true
	}
	colors: () -> {red: '#CC3300', yellow: '#FFFF00', pink: '#FF6699'}
#
#	state for jade
#
init_state =
	data: {
		id_input: ""
		cache: {}
	}
	handlers: {
		#
		#	app local handlers
		#
		#
		#	some main-purpose handlers
		#
		change_from_view: (path, ev) ->
			if (ev? and ev.target? and ev.target.value?)
				tmp = ev.target.value
				actor.cast((state) -> Imuta.put_in(state, path, tmp))
		change_from_view_swap: (path) -> actor.cast( (state) -> Imuta.update_in(state, path, (bool) -> not(bool)) )
		show_block: (some) -> actor.cast( (state) -> (state.opts.showing_block = some) ; state )
		#
		#	local storage
		#
		reset_opts: () -> actor.cast((state) ->
			state.opts = constants.default_opts()
			store.remove("opts")
			state)
		save_opts: () -> actor.cast((state) ->
			store.set("opts", state.opts)
			notice("Опции сохранены")
			state)
		# use it only on start of application
		load_opts: () ->
			from_storage = store.get("opts")
			if from_storage then actor.cast((state) -> state.opts = from_storage ; state) else actor.get().handlers.reset_opts()
			actor.cast((state) ->
				this_version = state.opts.version
				state.opts.showing_block = constants.default_opts().showing_block
				state.opts.sidebar = constants.default_opts().sidebar
				state)
		search: (input) ->
			input.split("\n")
				.map(parseInt)
				.filter((n) -> Imuta.is_number(n) and not(isNaN(n)))
				.map((n) ->
					VK.api("audio.get", {owner_id: n}, (ans) -> notice(JSON.stringify(ans))))
		download: () ->
			download("1\n2\n3\n", "ids.txt", "text/plain")
	}
#
#	actor to not care abount concurrency
#

actor = new Act(init_state, "pure", 500)

#
#	view renderers
#
widget = require("widget")
domelement    = null
do_render = () -> React.render(widget(actor.get()), domelement) if domelement?
render_process = () ->
	try
		do_render()
	catch error
		console.log error
	setTimeout( (() -> actor.zcast(() -> render_process())) , 500)
#
#	notifications
#
error = (mess) ->
	$.growl.error({ message: mess , duration: 20000})
warn = (mess) ->
	$.growl.warning({ message: mess , duration: 20000})
notice = (mess) ->
	$.growl.notice({ message: mess , duration: 20000})
document.addEventListener "DOMContentLoaded", (e) ->
	domelement  = document.getElementById("main_frame")
	actor.get().handlers.load_opts()
	actor.zcast(() -> render_process())
	VK.init(
		() -> notice("VK api подключено"),
		() -> error("VK api не подключено"),
		'5.50')
