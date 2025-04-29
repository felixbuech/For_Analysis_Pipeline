function metadataBehav = for_bidsEventsDescr()
%FOR_BIDSEVENTSDESCR This function describes the variables of the BIDS events file
%
%   Input
%       None
%
%   Output
%       metadataBehav: Meta data for behavioral variables

% Create structure
metadataBehav = struct();

% ID
metadataBehav.ID.LongName = 'subject ID';
metadataBehav.ID.Description = 'Numbers start from 1 to maximum number of subjects';
metadataBehav.ID.Units = 'integers';

% block
metadataBehav.block.LongName = 'condition block';
metadataBehav.block.Description = 'Block number within each condition';
metadataBehav.block.levels = 'integers';

% newBlock
metadataBehav.block.LongName = 'new block';
metadataBehav.block.Description = 'Indicates when new block begins';
metadataBehav.block.levels = 'integers';

% x_t
metadataBehav.x_t.LongName = 'x_t';
metadataBehav.x_t.Description = 'Current outcome';
metadataBehav.x_t.Units = 'integers';

% b_t
metadataBehav.b_t.LongName = 'b_t';
metadataBehav.b_t.Description = 'Current prediction';
metadataBehav.b_t.Units = 'integers';

% delta_t
metadataBehav.delta_t.LongName = 'prediction error';
metadataBehav.delta_t.Description = 'Difference between outcome and prediction';
metadataBehav.delta_t.Units = 'integers';

% a_t
metadataBehav.a_t.LongName = 'update';
metadataBehav.a_t.Description = 'Difference between two predictions';
metadataBehav.a_t.Units = 'integers';

% e_t
metadataBehav.e_t.LongName = 'estimation error';
metadataBehav.e_t.Description = 'Difference mean and prediction';
metadataBehav.e_t.Units = 'integers';

% mu_t
metadataBehav.mu_t.LongName = 'Cannon aim';
metadataBehav.mu_t.Description = 'Mean of the outcome generating distribution (cannon aim)';
metadataBehav.mu_t.Units = 'integers';

% c_t
metadataBehav.c_t.LongName = 'change point';
metadataBehav.c_t.Description = 'Indicates if changepoint occurred';
metadataBehav.c_t.levels = {'0: No changepoint', '1: Changepoint'};

% tac
metadataBehav.tac.LongName = 'trials after change point';
metadataBehav.tac.Description = 'Counts the number of outcomes after last change point';
metadataBehav.tac.Units = 'integers';

% r_t
metadataBehav.r_t.LongName = 'hit';
metadataBehav.r_t.Description = 'Indicates if cannonball was caught or missed';
metadataBehav.r_t.levels = {'0: Miss', '1: Hit'};

% kappa_t
metadataBehav.kappa_t.LongName = 'concentration';
metadataBehav.kappa_t.Description = 'Concentration of cannon distribution';
metadataBehav.kappa_t.Units = 'float';

% v_t
metadataBehav.v_t.LongName = 'catch trials';
metadataBehav.v_t.Description = 'Indicates if cannon was visible or not';
metadataBehav.v_t.levels = {'0: No catch trial', '1: Catch trial'};

% RT:
metadataBehav.RT.LongName = 'reaction time';
metadataBehav.RT.description = 'Indicates the time to prediction. Note that we also recorded initiation RTs, indicating time to movement';
metadataBehav.RT.Units = 'float';

% initRT
metadataBehav.initRT.LongName = 'initiation reaction time';
metadataBehav.initRT.description = 'Indicates the time to movement initiation. Note that we also recorded RTs, indicating time to prediction';
metadataBehav.initRT.Units = 'float';

end





