using JuMP, SCIP, DataFrames, CSV

struct Technician
    name::String
    cap::Int64
    depot::String
end

struct Job
    name::String
    priority::Int64
    duration::Int64
    coveredBy::Array{String,1}
end

struct Customer
    name::String
    loc::String
    job::Job
    tStart::Int64
    tEnd::Int64
    tDue::Int64
end

function loadproblem()

    ####################
    # Technicians data #
    ####################

    # Read technicians data
    technicians_file = CSV.read("data/technicians.txt",DataFrame)
    #println(technicians_file)

    technicians = [Technician(row["Name"],
                              row["Capacity"],
                              row["Depot"]) for row in eachrow(technicians_file)]

    #@show technicians
    #return technicians,0

    #################
    # Jobs data #
    #################

    # Read services data
    jobs_file = CSV.read("data/jobs.txt",DataFrame)
    #println(jobs_file)

    # Read technician-services data
    technicians_jobs_file = CSV.read("data/technicians_jobs.txt",DataFrame)
    #println(technicians_jobs_file)

    cobertura_servicos = Dict([row["Job Type"] => [] for row in eachrow(jobs_file)])
    for row in eachrow(technicians_jobs_file)
        job = row["Job"]
        technician = row["Technician"]
        tempo = cobertura_servicos[job]
        push!(tempo, technician)
        cobertura_servicos[job] = tempo
    end
    
    #@show cobertura_servicos
    #return technician_services_file

    jobs = [Job(row["Job Type"], 
                row["Priority"], 
                row["Duration (min)"], 
                cobertura_servicos[ row["Job Type"] ])
            for row in eachrow(jobs_file)]

    #@show jobs
    #return jobs, 0



    ##################
    # Locations data #
    ##################
    # Read locations data
    locations_file = CSV.read("data/locations.txt",DataFrame)
    #println(locations_file)

    # Build useful data structures
    L = String.(unique(locations_file[:,"Location Start"]))
    locations_End = unique(locations_file[:,"Location End"])
    for l in locations_End
        if !(l in L)
            push!(L,String(l))
        end
    end
    
    #return locations,0

    dist = Dict([(l, l) => 0 for l in L])
    for row in eachrow(locations_file)
        saida = row["Location Start"]
        chegada = row["Location End"]
        tempo = row["Tempo Viagem"]
        dist[(saida,chegada)] = tempo
        dist[(chegada,saida)] = tempo
    end
    
    #@show dist
    #return dist,0
    
    ##################
    # Customers data #
    ##################
    # Read customers data
    customers_file = CSV.read("data/customers.txt",DataFrame)
    #println(customers_file)

    customers = Customer[]
    for row in eachrow(customers_file)
        for job in jobs
            if row["Job Type"] == job.name
                thisCustomer = Customer(row["Name"],
                                        row["Location"],
                                        job,
                                        row["Time window Start"],
                                        row["Time window end"],
                                        row["Due time"])
                push!(customers,thisCustomer)
            end
        end
    end

    #@show customers
    #return customers, 0
    
    K = [k.name for k in technicians]
    C = [j.name for j in customers]
    J = [j.loc for j in customers]
    D = String.(unique(technicians_file.Depot))
    cap = Dict([k.name => k.cap for k in technicians])
    loc = Dict([j.name => j.loc for j in customers])
    depot = Dict([k.name => k.depot for k in technicians])
    canCover = Dict([j.name => j.job.coveredBy for j in customers])
    dur = Dict([j.name => j.job.duration for j in customers])
    tStart = Dict([j.name => j.tStart for j in customers])
    tEnd = Dict([j.name => j.tEnd for j in customers])
    tDue = Dict([j.name => j.tDue for j in customers])
    priority = Dict([j.name => j.job.priority for j in customers])
    

    #=
    @show K
    @show C
    @show J
    @show L
    @show D
    @show cap
    @show loc
    @show depot
    @show canCover
    @show dur
    @show tStart
    @show tEnd
    @show tDue
    @show priority
    =#

    return technicians,customers,dist,
           K,C,J,L,D,
           cap,loc,depot,canCover,dur,tStart,tEnd,tDue,priority
end


function experimento()

    technicians,customers,dist,K,C,J,L,D,
    cap,loc,depot,canCover,dur,tStart,tEnd,tDue,priority = loadproblem()

    model = Model(SCIP.Optimizer)
    
    ######################
    # Decision variables #
    ######################

    # Customer-technician assignment
    @variable(model,x[C,K],Bin)

    # Technician assignment
    @variable(model,u[K],Bin)

    # Edge-route assignment to technician
    @variable(model,y[L,L,K],Bin)

    # Technician cannot leave or return to a depot that is not its base
    for k in technicians
        for d in D
            if k.depot != d
                for i in L
                    JuMP.set_upper_bound(y[i,d,k.name],0)
                    JuMP.set_upper_bound(y[d,i,k.name],0)
                end
            end
        end
    end

    # Start time of service
    @variable(model, 0 <= t[L] <= 600,Int)

    # Lateness of service
    @variable(model,z[C] >= 0,Int)

    # Artificial variables to correct time window upper and lower limits
    @variable(model,xa[C] >= 0,Int)
    @variable(model,xb[C] >= 0,Int)

    # Unfilled jobs
    @variable(model,g[C],Bin)

    ###############
    # Constraints #
    ###############

    # A technician must be assigned to a job, or a gap is declared (1)
    for j in C
        constraint = @constraint(model,sum(x[j,k] for k in canCover[j]) + g[j] == 1)
        JuMP.set_name(constraint, "assignToJob[$j]")
    end

    # At most one technician can be assigned to a job (2)
    for j in C
        constraint = @constraint(model, sum(x[j,k] for k in K) <= 1)
        JuMP.set_name(constraint, "assignOne[$j]")
    end
    
    print(model)

end



experimento()
println("ok")
#technicians,customers,dist,K,C,J,L,D,
#cap,loc,depot,canCover,dur,tStart,tEnd,tDue,priority = loadproblem()