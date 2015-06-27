import Patchwork: Elem, diff, jsonfmt
import Electron
import JSON

const PWPath = Pkg.dir("Patchwork", "runtime")

assoc(key, value, d::Dict) = begin
  d = copy(d)
  d[key] = value
  d
end

function rutherford(guiᵗ::Task, options::Associative)
  port,server = listenany(3000)
  proc = start_electron(assoc(:query, [:port => port, :PWPath => PWPath], options))
  sock = accept(server)

  renderer = @schedule try
    gui = consume(guiᵗ)

    # Send over initial rendering
    write(sock, gui |> jsonfmt |> JSON.json, '\n')

    # Write patches
    for nextGUI in guiᵗ
      patch = diff(gui, nextGUI) |> jsonfmt |> JSON.json
      write(sock, patch, '\n')
      gui = nextGUI
    end
  finally
    kill(proc)
    close(server)
  end

  # Produce a series of events
  eventᵗ = @task for line in eachline(sock)
    produce(JSON.parse(line))
  end

  return eventᵗ,renderer
end

function start_electron(params)
  stdin,process = open(`$(Electron.path) app`, "w")
  write(stdin, JSON.json(params), '\n')
  close(stdin)
  process
end
