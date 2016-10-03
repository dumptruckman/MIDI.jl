function type1totype0(data::MIDIFile)
	if data.format != UInt8(1)
		error("Got type $(data.format); expecting type 1")
	end
	if dochannelsconflict(getprogramchangeevents(data))
		error("Conversion failed since different tracks 
		patch different instruments to the same channel.
		Use getprogramchangeevents for inspection.")
	end
	for track in data.tracks
		toabsolutetime(track)
	end
	for track in data.tracks[2:end]
		insertsorted!(data.tracks[1].events, track.events)
	end
	data.tracks = data.tracks[1:1]
	fromabsolutetime(data.tracks[1])
	data.format = 0
end
export type1totype0

function insertsorted!(events1::Array{TrackEvent, 1}, 
					   events2::Array{TrackEvent, 1})
	map(x -> insertsorted!(events1, x), events2)
end

function insertsorted!(events1::Array{TrackEvent, 1}, 
					   event::TrackEvent)
	i = 0
	while events1[end - i].dT > event.dT
		i += 1
	end
	insert!(events1, length(events1) - i + 1, event)
end

function toabsolutetime(track::MIDITrack)
	t = Int64(0)
	for event in track.events
		t += event.dT
		event.dT = t
	end
end

function fromabsolutetime(track::MIDITrack)
	t0 = t1 = Int64(0)
	for event in track.events
		t1 = event.dT
		event.dT = event.dT - t0
		if event.dT < 0
			error("Negative relative dT")
		end
		t0 = t1
	end
end

function getprogramchangeevents(data::MIDIFile)
	pgevents = []
	t = 0
	for track in data.tracks
		t += 1
		i = 0
		for event in track.events
			i += 1
			if typeof(event) == MIDIEvent && 
					(0xF0 & event.status) $ PROGRAMCHANGE == 0
				push!(pgevents, [t, i, event])
			end
		end
	end
	pgevents
end
export getprogramchangeevents

function dochannelsconflict(pgevents)
	channels = Dict()
	for pgevent in pgevents
		newkey = pgevent[3].status
		if haskey(channels, newkey)
			if channels[newkey][1] != pgevent[1] &&
				channels[newkey][2] != pgevent[3].data[1]
				return true
			end
		else
			channels[newkey] = (pgevent[1], pgevent[3].data[1])
		end
	end
	false
end

