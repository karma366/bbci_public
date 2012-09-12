function out= proc_average(epo, varargin)
%PROC_AVERAGE - Classwise calculated averages
%
%Synopsis:
% EPO= proc_average(EPO, <OPT>)
% EPO= proc_average(EPO, CLASSES)
%
%Arguments:
% EPO -      data structure of epoched data
%            (can handle more than 3-dimensional data, the average is
%            calculated across the last dimension)
% OPT struct or property/value list of optional arguments:
%  .policy - 'mean' (default), 'nanmean', or 'median'
%  .std    - if true, standard deviation is calculated also 
%  .classes - classes of which the average is to be calculated,
%            names of classes (strings in a cell array), or 'ALL' (default)
%
% For compatibility PROC_AVERAGE can be called in the old format with CLASSES
% as second argument (which is now set via opt.Classes):
% CLASSES - classes of which the average is to be calculated,
%           names of classes (strings in a cell array), or 'ALL' (default)
%
%Returns:
% EPO     - updated data structure with new field(s)
%  .N     - vector of epochs per class across which average was calculated
%  .std   - standard deviation, if requested (opt.Std==1),
%           format as epo.x.

% Benjamin Blankertz


props= {  'Policy'   'mean' '!CHAR(mean nanmean median)'
          'Classes' 'ALL'   '!CHAR'
          'Std'      0      '!BOOL'  };

if nargin==0,
  out = props; return
end

misc_checkType(epo, 'STRUCT(x clab y)'); 
if nargin==2
  opt.Classes = varargin{:};
else
  opt= opt_proplistToStruct(varargin{:});
end
[opt, isdefault]= opt_setDefaults(opt, props);
opt_checkProplist(opt, props);        
epo = misc_history(epo);

%% delegate a special case:
if isfield(epo, 'yUnit') && isequal(epo.yUnit, 'dB'),
  out= proc_dBAverage(epo, varargin{:});
  return;
end

%%		  
classes = opt.Classes;

if ~isfield(epo, 'y'),
  warning('no classes label found: calculating average across all epochs');
  nEpochs= size(epo.x, ndims(epo.x));
  epo.y= ones(1, nEpochs);
  epo.className= {'all'};
end

if isequal(opt.Classes, 'ALL'),
  classes= epo.className;
end
if ischar(classes), classes= {classes}; end
if ~iscell(classes),
  error('classes must be given cell array (or string)');
end
nClasses= length(classes);

if max(sum(epo.y,2))==1,
  warning('only one epoch per class - nothing to average');
  out= proc_selectClasses(epo, classes);
  out.N= ones(1, nClasses);
  return;
end

out= epo;
%  clInd= find(ismember(epo.className, classes));
%% the command above would not keep the order of the classes in cell 'ev'
evInd= cell(1,nClasses);
for ic= 1:nClasses,
  clInd= find(ismember(epo.className, classes{ic}));
  evInd{ic}= find(epo.y(clInd,:));
end

sz= size(epo.x);
out.x= zeros(prod(sz(1:end-1)), nClasses);
if opt.Std,
  out.std= zeros(prod(sz(1:end-1)), nClasses);
  if exist('mrk_addIndexedField')==2,
    %% The following line is only to be executed if the BBCI Toolbox
    %% is loaded.
    out= mrk_addIndexedField(out, 'std');
  end
end
out.y= eye(nClasses);
out.className= classes;
out.N= zeros(1, nClasses);
epo.x= reshape(epo.x, [prod(sz(1:end-1)) sz(end)]);
for ic= 1:nClasses,
  switch(lower(opt.Policy)),  %% alt: feval(opt.Policy, ...)
   case 'mean',
    out.x(:,ic)= mean(epo.x(:,evInd{ic}), 2);
   case 'nanmean',
    out.x(:,ic)= nanmean(epo.x(:,evInd{ic}), 2);
   case 'median',
    out.x(:,ic)= median(epo.x(:,evInd{ic}), 2);
   otherwise,
    error('unknown policy');
  end
  if opt.Std,
    if strcmpi(opt.Policy,'nanmean'),
      out.std(:,ic)= nanstd(epo.x(:,evInd{ic}), 0, 2);
    else
      out.std(:,ic)= std(epo.x(:,evInd{ic}), 0, 2);
    end
  end
  out.N(ic)= length(evInd{ic});
end

out.x= reshape(out.x, [sz(1:end-1) nClasses]);
if opt.Std,
  out.std= reshape(out.std, [sz(1:end-1) nClasses]);
end