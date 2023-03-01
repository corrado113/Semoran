% Copyright (c) 2022-2023 Corrado Puligheddu
function [s, x, z, total_value] = semoran(a,l,A,L,S,O,p,actions,min_s)
% SEMORAN computes the Semantic Flexible Edge Slicing Problem solution
%   [s,x,z,total_value] = semoran(a,l,A,L,S,O,p,actions) solves the
%   Semantic Flexible Edge Slicing Problem (SF-ESP).
%
%   It takes as input:
%   - a: a cell array of accuracy functions a_tau(z) that take as input
%   the compression factor scalar z and return the corresponding accuracy,
%   defined for each task
%   - l: a cell array of latency functions l_tau(s,z) that take as input
%   the resource allocation vector s and the compression factor scalar z,
%   and return the corresponding end-to-end latency, defined for each task
%   - A: an array of accuracy requirements that have to be satisfied by
%   each task
%   - L: an array of latency requirements that have to be satisfied by each
%   task
%   - S: an array containing the total resource capacity available to be
%   allocated to tasks; its size is equal to the number of resource types
%   - O: an array of offers/priorities for each task
%   - p: an array of prices of each resource type
%   - actions: cell array of allowed actions, which comprises resource
%   allocations of each resource type and compression factors (last); 
%   each cell element is an array containing the allowed values
%
%   It returns:
%   - s: the resouce allocation matrix, containing the allocated resources
%   for each task and resource type
%   - x: the admission vector, containing for each task 1 if the task is
%   admitted, 0 otherwise
%   - z: the compression factor vector, containing for each task the
%   selected compression factor
%   - total_value: the scalar value of the objective function
%
%   [s,x,z,total_value] = semoran(a,l,A,L,S,O,p,actions,min_s) solves the
%   SF-ESP always allocating the minimum amount of resources sufficient to
%   execute admitted tasks within constraints, thus without enabling 
%   flexible resource allocation
%   It takes the input defined above, plus min_s: a boolean that has to be
%   set to true that enables this solver behavior. It returns the same
%   outputs as defined above.

    m = length(S);
    T = length(L);
    assert(T == length(a) && T == length(l) && T == length(A), ...
        "Item size "+string(T)+" is not consistent across all inputs");
    assert(m == length(p), "S and p must have the same length");
    assert(length(O) == T, "O length must equal to the number of tasks");
    assert(exist('actions','var'));
    assert(numel(actions) == m+1, "Actions variable size must be m+1");
    %disp("Discrete actions");
    assert(iscell(actions), "Actions variable must have cell type");
    if exist('min_s', 'var')
        assert(min_s == true);
    end
    % reshape input variables
    S = S(:); % S is column
    O = O(:); % O is same shape as S
    p = p(:)'; % p is row
    
    % initialize return variables
    z = zeros([T,1]);
    s = zeros([m,T]);
    x = zeros([T,1]);
    
    % define allowed actions
    out = cell(size(actions));
    [out{:}] = ndgrid(actions{:});
    ac=zeros([length(out)-1, numel(out{1})]);
    for i=1:length(out)-1
        ac(i,:) = out{i}(:);
    end
    
    % if P is 0s then replace it with 1s
    replace_P = @(P)P*any(P>0)+all(P==0)*ones([m,1]); 
    primal_gradient = @(s_t, t) (O(t)-p*s_t)*norm(replace_P(s*x))/ ...
        sum(s_t./S.*replace_P(s*x));
    
    % find the optimal compression factor for all items starting from the
    % accuracy functions. argmin(a) s.t. accuracy requirement is met.  
    % find an initial weight for each item to perform a preliminary sorting
    z = optimal_z(z);
    if exist('min_s', 'var')
        s = optimal_s(z,s);
    end

    % admit task according to the order of their primal gradient
    % keep going if there are feasible task that are not admitted yet
    candidate_task = logical(true([T,1]));
    for t = 1:T
        if a{t}(z(t)) < A(t)
            candidate_task(t) = false;
        end
        if exist('min_s', 'var')
            if sum(s(:,t)) == 0
                candidate_task(t) = false;
            elseif l{t}(s(:,t),z(t)) > L(t)
                candidate_task(t) = false;
            end
        end
    end
    while true
        candidate_task_set = find(candidate_task);
        G = zeros([T,1]);

        if isempty(candidate_task_set)
            break
        end
        % calculate the primal gradient of candidate tasks
        for c = 1:length(candidate_task_set)
            t = candidate_task_set(c);
            if exist('min_s', 'var')
            % gradients only depends on free resources
                G(t) = primal_gradient(s(:,t),t);
                continue
            end

            [s(:,t), G(t)] = find_maximum_gradient(t);
            if all(s(:,t) == 0)
                candidate_task(t) = false;
            end
        end
        % calculate the max gradient and accept the corresponding task
        [g, c] = max(G);
        if candidate_task(c)
            x(c) = 1;
        else
            continue;
        end
        candidate_task(c) = false;
        
        if exist('min_s', 'var')
            %remove candidate that are not feasible anymore
            for c = 1:length(candidate_task_set)
                t = candidate_task_set(c);
                if any(s(:,t) >  S - s*x)
                    candidate_task(t) = false;
                end
            end
        end
    end   
    
    total_value = (O-p*s)*x;
    
    % try to accept feasible tasks
    % feasible only if it satisfies performance and resource constraints
    function f = check_task_feasibility
        f = logical(false([T,1]));
        for t = 1:T
%             if a{t}(z(t)) => A(t) && ...
%                 l{t}(min_s(:,t),z(t)) <= L(t) && ...
%                 all(min_s(:,t) <= S + s*x)
            if a{t}(z(t) > A(t))
                disp("Task "+ t +" is feasible");
                f(t) = true;
            end        
        end
    end

    function z = optimal_z(z)
        z_values = sort(actions{end});
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

    function s = optimal_s(z,s) 
        [s_values,idx] = sort(O-p*ac, 'descend');
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
    function [s_t, max_gradient] = find_maximum_gradient(t)
        % find the feasible resource allocation that maximizes the gradient 
        max_gradient = 0;
        s_t = zeros([m,1]);
        % forall possible actions
        % if action is feasible find gradient
        % if current gradient is greater than the max we previously had,
        % update the max gradient
        % return the max gradient and the corresponding resource allocation
        for i = 1:length(ac)
            if feasible(t,ac(:,i))
                gradient = primal_gradient(ac(:,i),t);
                if gradient > max_gradient
                    max_gradient = gradient;
                    s_t = ac(:,i);
                end
            end
        end
        
        function f = feasible(t,s_t)
            f = false;
            if all(S-s*x >= s_t) && l{t}(s_t,z(t)) < L(t)
                f = true;
            end
        end
    end
end