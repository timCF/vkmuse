#
#	close modal
#

#closemodal = () ->
#	el = document.getElementsByClassName("box_x_button")[0]
#	console.log(el)
#	if el then el.dispatchEvent(new MouseEvent("click", { "view": window, "bubbles": true, "cancelable": false }))
#setInterval(closemodal, 3000)

#
#	constants, defaults as callbacks arity 0
#
constants =
	default_opts: () -> {
		blocks: [{val: "main_page", lab: "данные"},{val: "opts", lab: "опции"}]
		sidebar: false
		showing_block: "main_page"
		version: '__VERSION__'
		search_subject: "users"
		search_type: "substring"
		search_object: "audio"
		search_param: "artist"
	}
	colors: () -> {red: '#CC3300', yellow: '#FFFF00', pink: '#FF6699'}
#
#	state for jade
#
init_state =
	data: {
		id_input: ""
		search_artist: ""
		search_title: ""
		cache: {}
		search_result: []
		is_locked: false
		pbar_total: 0
		pbar_ok: 0
		pbar_failed: 0
		pbar_processed: 0
		pbar_emergency: 0
	}
	handlers: {
		#
		#	app local handlers
		#
		search_process_callback: (ans, el, todo, n_total, n_ok, n_failed, n_emergency, acc) ->
			actor.cast((state) ->
				state.data.pbar_ok = 100 * (n_ok / n_total)
				state.data.pbar_failed = 100 * (n_failed / n_total)
				state.data.pbar_emergency = 100 * (n_emergency / n_total)
				state.data.pbar_rest = 100 * ((n_total - n_ok - n_failed - n_emergency) / n_total)
				lambda_ok = () ->
					notice(JSON.stringify(ans))
					setTimeout((() -> state.handlers.search_process(todo, n_total, n_ok + 1, n_failed, n_emergency, [el, acc...])), 1)
				lambda_failed = () ->
					warn(JSON.stringify(ans))
					setTimeout((() -> state.handlers.search_process(todo, n_total, n_ok, n_failed + 1, n_emergency, acc)), 1)
				lambda_emergency = () ->
					error(JSON.stringify(ans))
					setTimeout((() -> state.handlers.search_process(todo, n_total, n_ok, n_failed, n_emergency + 1, acc)), 1)
				if Imuta.is_map(ans) and Imuta.is_map(ans.response) and Imuta.is_list(ans.response.items)
					search_param = (if (state.opts.search_object == "video") then "title" else state.opts.search_param)
					search_list = state.data["search_"+search_param].split("\n").map($.trim)
					switch state.opts.search_type
						when "substring"
							if search_list.some((search_string) -> ans.response.items.some((el) -> el[search_param].toUpperCase().indexOf(search_string.toUpperCase()) != -1)) then lambda_ok() else lambda_failed()
						when "direct"
							if search_list.some((search_string) -> ans.response.items.some((el) -> $.trim(el[search_param]).toUpperCase() == search_string.toUpperCase())) then lambda_ok() else lambda_failed()
				else
					lambda_emergency()
				state)
		search_process: ([el, todo...], n_total, n_ok, n_failed, n_emergency, acc) ->
			if (todo.length == 0) and (el == undefined)
				actor.cast((state) ->
					state.data.is_locked = false
					state)
				if (acc.length == 0)
					error("no any objects for request")
				else
					notice("found "+acc.length+" objects")
					download(acc.join("\r\n"), Date()+".txt", "text/plain")
			else
				actor.cast((state) ->
					owner_id = (if (state.opts.search_subject == "users") then Math.abs(el) else (-1 * Math.abs(el)))
					switch state.opts.search_object
						when "audio"
							VK.api("audio.get", {owner_id: owner_id, v: 5.50}, (ans) -> state.handlers.search_process_callback(ans, el, todo, n_total, n_ok, n_failed, n_emergency, acc))
						when "video"
							VK.api("video.get", {owner_id: owner_id, v: 5.50}, (ans) -> state.handlers.search_process_callback(ans, el, todo, n_total, n_ok, n_failed, n_emergency, acc))
					state)

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
		search: () ->
			actor.cast((state) ->
				state.data.is_locked = true
				todo = state.data.id_input.split("\n")
						.map($.trim)
						.reduce(((acc, el) -> acc[el] = true ; acc), {})
				todo = Object.keys(todo)
				state.data.is_locked = true
				state.handlers.search_process(todo, todo.length, 0, 0, 0, [])
				state)
	}
#
#	actor to not care abount concurrency
#

actor = new Act(init_state, "pure", 300)

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
	$.growl.error({ message: mess , duration: 700})
warn = (mess) ->
	$.growl.warning({ message: mess , duration: 700})
notice = (mess) ->
	$.growl.notice({ message: mess , duration: 700})
#
#	main
#
document.addEventListener "DOMContentLoaded", (e) ->
	domelement  = document.getElementById("main_frame")
	actor.get().handlers.load_opts()
	actor.zcast(() -> render_process())
	VK.init(
		() -> notice("VK api connected"),
		() -> error("VK api NOT connected"),
		'5.50')
