%% 
% Copyright (c) 2022-2023 Corrado Puligheddu
%% SEM-O-RAN example
% In this file we provide an example on how to use the SF-ESP solver provided 
% in the semoran.m file and a comparison between SEM-O-RAN and a baseline.

requested_tasks = 10;

actions = {1:15, [0.2, 0.5, 1:8], 0:2:32, 0:2, 1./[1:10]};

S = [25,16,128,2]; % total resource
p = 1./S;          % resource price

% preallocate variables
O = zeros([requested_tasks, 1]);
A = zeros([requested_tasks, 1]);
L = zeros([requested_tasks, 1]);
a =  cell([requested_tasks, 1]);
l =  cell([requested_tasks, 1]);

% create some fictional tasks
for t=1:requested_tasks
    O(t) = randi([1,50]);
    
    A(t) = randi([25;60])/100; % accuracy requirement uniform in [0.3, 0.6]
    L(t) = randi([10,40])/100; %  latency requirement uniform in [.06, 0.4]
    
    % class maximum accuracy uniform between 0.1 and 0.7
    a{t} = make_analytical_accuracy(randi([10,70])/100);
    
    % latency according to fps, uniform between 1 and 30
    l{t} = make_analytical_latency(randi([1,30]));
end

%% 
% Run SEM-O-RAN:


[s,x,z,~] = semoran(a,l,A,L,S,O,p,actions);

[accepted_tasks, within_constraints, solution_score] = ...
    verify_solver_performance(a,l,A,L,S,O,p,actions,s,x,z)
%% 
% Run a baseline competitor, a knapsack solver able to leverage semantics:

z = optimal_z(a,A,actions);
s = minimum_s(z,l,L,p,actions);

[x,~] = greedy_knapsack(s,S,O,p);
[accepted_tasks, within_constraints, solution_score] = ...
    verify_solver_performance(a,l,A,L,S,O,p,actions,s,x,z)
%% 
% 

function s = minimum_s(z,l,L,p,actions)
% Calculate minimum resource allocation for tasks
    m = length(actions)-1;
    T = length(l);
    s = zeros([m,T]);
    out = cell(size(actions));
    [out{:}] = ndgrid(actions{:});
    
    ac=zeros([length(out)-1, numel(out{1})]);
    for i=1:length(out)-1
        ac(i,:) = out{i}(:);
    end
    [s_values,idx] = sort(p*ac);
    for t = 1:T
        if z(t) == 0
            continue
        end
        found = false;
        for s_i = 1:length(s_values)
            s(:,t) = ac(:,idx(s_i));
            if l{t}(s(:,t),z(t)) <= L(t)
                found = true;
                break;
            end
        end
        if ~ found
            s(:,t) = zeros([m,1]);
        end
    end
end

function z = optimal_z(a,A,actions)
% Calculate optimal compression factor for tasks
    T = length(a);
    z_values = sort(actions{end});
    z = zeros([T,1]);
    for t = 1:T
        found = false;
        for z_i = 1:length(z_values)
            z(t) = z_values(z_i);
            if a{t}(z(t)) >= A(t)
                found = true;
                break;
            end
        end
        if ~ found
            z(t) = 0;
        end
    end
end

function [accepted_tasks, within_constraints, solution_score] = ...
    verify_solver_performance(a,l,A,L,S,O,p,actions,s,x,z,~)
% Verify how many accepted tasks are executed within accuracy and latency
% constraints. Also provide the real solution score, penalizing tasks
% executed without meeting the constraints
    T = length(x);
    m = length(S);
    O = O(:)'; % row vector
    accepted_tasks = length(x(x>0));
    within_constraints = 0;
    solution_score = 0;
    % verify that resource allocation is part of feasible actions and that
    % knapsack constraints are satisfied
    feasible_solution = true;
    for k=1:m
        if ~all(ismember(s(k,x>0),actions{k}))
            feasible_solution = false;
            disp("Found unfeasible action for dim "+k);
        end
    end
    if length(actions) > m
        if ~ismember(z(x>0),[actions{end},0])
            feasible_solution = false;
            disp("Found unfeasible compression factor");
        end
    end
    if any(s*x>S)
        feasible_solution = false;
        disp("Total resources exceeded")
    end
    if ~feasible_solution
        disp("Invalid solution");
        solution_score = 0;
        return;
    end
    for t = 1:T
        if x(t) == 0
            continue;
        end
        solution_score = solution_score - p*s(:,t);
        if a{t}(z(t)) >= A(t) && l{t}(s(:,t),z(t)) <= L(t)
            within_constraints = within_constraints + 1;
            solution_score = solution_score + O(t);
        end
    end
end

function latency_fn = make_analytical_latency(fps)
% return a latency function without needing a dataset
    latency_fn = @latency_function;
    function l = latency_function(s,z)
        resources = s(2); %gpu
        if length(s) > 2
            resources = resources + 1/5*s(3); %CPU
        end
        if length(s) > 3
            resources = resources + 5*s(4); %TPU
        end
        if length(s) > 4
            resources = resources + 1/8*s(5); %RAM
        end
        processing = fps^1.1*100/resources;
        networking = 50+5/4*z*fps/s(1);
        l = (networking + processing)/1000;
    end
end

function accuracy_fn = make_analytical_accuracy(h)
% return an accuracy function without needing a dataset
    accuracy_fn = @accuracy_function;
    function a = accuracy_function(z)
        a = h * z;
    end
end

function accuracy_fn = make_accuracy(class_set)
% example of a accuracy function factory able to use real data
    dump = load("accuracy_set.mat", "polycoeff", "classes_set_strings");
    accuracy_coeff = dump.polycoeff;
    classes_strings = dump.classes_set_strings;
    if isstring(class_set)
        class_set = classes_strings==class_set;
    end
    assert(any(class_set), "Class set not found");
    accuracy_fn = @accuracy_function;
    function a = accuracy_function(z)
        a = polyval(accuracy_coeff(class_set,:),z);
    end
end
function latency_fn = make_latency(fps)
% example of a latency function factory able to use real data
    warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');
    t = readtable("../latency_result2.csv");
    t.z = 1./t.sf;
    t = t(t.fps == fps,:);
    assert(~isempty(t), "Selected FPS value not found");
    latency_fn = @latency_function;
    function l = latency_function(s,z)
        rbg = s(1); gpu = s(2);
        l = t.mean(t.rbg == rbg & t.gpu == gpu & t.z == z);
        if isempty(l)
            disp("Latency not found: rbg "+rbg+", gpu "+gpu+" and z "+z);
            l = 5;
        end
    end
end