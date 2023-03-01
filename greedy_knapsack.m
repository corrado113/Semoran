% Copyright (c) 2022-2023 Corrado Puligheddu
function [x, total_value] = greedy_knapsack(s,S,O,p)
%GREEDY_KNAPSACK Use toyoda 1975 to allocate fixed size task
    [m,T] = size(s);
    % reshape input variables
    S = S(:); % S is column
    O = O(:); % O is same shape as S
    p = p(:)'; % p is row
    assert(length(p) == m);
    assert(length(S) == m);
    assert(length(O) == T);
    x = zeros([T,1]);
    
    replace_P = @(P)P*any(P>0)+all(P==0)*ones([m,1]); 
    primal_gradient = @(s_t, t) (O(t)-p*s_t)*norm(replace_P(s*x))/ ...
        sum(s_t./S.*replace_P(s*x));
    
    candidate_task = true([T,1]);
    candidate_task(all(s == 0)) = false;
    while true
        candidate_task_set = find(candidate_task);
        G = zeros([T,1]);

        if isempty(candidate_task_set)
            break
        end
        % calculate the primal gradient of candidate tasks
        for c = 1:length(candidate_task_set)
            t = candidate_task_set(c);
            % gradients only depends on free resources
            G(t) = primal_gradient(s(:,t), t);

        end
        % calculate the max gradient and accept the corresponding task
        [g, c] = max(G);
        if candidate_task(c)
            x(c) = 1;
        else
            continue;
        end
        candidate_task(c) = false;

        %remove candidate that are not feasible anymore
        for c = 1:length(candidate_task_set)
            t = candidate_task_set(c);
            if any(s(:,t) >  S - s*x)
                candidate_task(t) = false;
            end
        end
    end
    
    total_value = (O-p*s)*x;
end

