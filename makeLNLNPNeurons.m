%% LN-LNP Cascade for making tuned neurons
%
% First stage = "subunits"
%   First linear stage = convolutional subunits of multiple filters
%   First nonlinear stage = point-wise, simple rectification
%
% Second stage = Weighted sum rectified poisson firing rate
%   Second linear stage = pooling with +/- weights across first stage
%   Second nonlinear stage = simple rectification
%   Final step = poisson spiking output
%
% - See Vintch et al. Efficient and direct estimation of a neural subunit model for sensory coding. NIPS, 2012. 
% - Neural tuning ideas from Nagel and Wilson 2011
%
% SLH 2016
clear; clc
close all; 
%dbstop if error

%% Load in stimulus
FS = 5000; % Sample Rate
[stim, time] = generateStimuli(FS);

%% Make multiple neurons of each type
nNeurons = 20;
for iN = 1:nNeurons;
    
    %% Define neuron "types" by their pooled subunit properties

    % nX(i).use    defines which filters to use (6 total)
    % nX(i).mu     defines pdf center for filter values
    % nX(i).sigma  defines pdf std for filter values
    % nX(i).baseFR defines baseline firing rate for the class (will vary by 10%)
    % nX(i).modFR  defines 'modulated' firing rate for the class (will vary by 10%)
    % see makeSubunits for 

    % Neuron type-A OK
    nA(iN).use      = [     1       0       1       0       0       1       ];
    nA(iN).mu       = [     20      00  	02      00      00   	15      ]./1000;
    nA(iN).sigma    = [     05      00      01      00      00  	05      ]./1000;
    nA(iN).baseFR   = 10;
    nA(iN).modFR    = 14;
    % Neuron type-B OK   
    nB(iN).use      = [     0       1       1       0    	1       0       ];
    nB(iN).mu       = [     0      20      02       0       40      0       ]./1000;
    nB(iN).sigma    = [     0      10      01       0       80      0       ]./1000;
    nB(iN).baseFR   = 12;
    nB(iN).modFR    = 15;
    % Neuron type-C OK
    nC(iN).use      = [     0       0       1       1       0       0       ];
    nC(iN).mu       = [     00      0       06      08      0       0       ]./1000;
    nC(iN).sigma    = [     00      0       08      10      0       0       ]./1000;
    nC(iN).baseFR   = 12;
    nC(iN).modFR    = 22;

    %% Generate filters for each neuron type (the subunits)
    [nA(iN).filts,nA(iN).weights] = makeSubunits(nA(iN),FS);
    [nB(iN).filts,nB(iN).weights] = makeSubunits(nB(iN),FS);
    [nC(iN).filts,nC(iN).weights] = makeSubunits(nC(iN),FS);

    %% Get spike rasters and pooled output
    binMs = 1;
    nReps = 100;
    [nA(iN).rasters,nA(iN).pools] = getModelResponses(nA(iN).filts,nA(iN).weights,stim,nA(iN).baseFR,nA(iN).modFR,binMs,nReps,FS);
    [nB(iN).rasters,nB(iN).pools] = getModelResponses(nB(iN).filts,nB(iN).weights,stim,nB(iN).baseFR,nB(iN).modFR,binMs,nReps,FS);
    [nC(iN).rasters,nC(iN).pools] = getModelResponses(nC(iN).filts,nC(iN).weights,stim,nC(iN).baseFR,nC(iN).modFR,binMs,nReps,FS);
    
    %% Make sdfs & psths for each neuron's responses
    for iS = 1:size(stim,1)
        [nA(iN).sdf(iS,:),nA(iN).psth(iS,:)] = spikeDensityFunction(nA(iN).rasters{iS},binMs,FS,binMs*4);
        [nB(iN).sdf(iS,:),nB(iN).psth(iS,:)] = spikeDensityFunction(nB(iN).rasters{iS},binMs,FS,binMs*4);
        [nC(iN).sdf(iS,:),nC(iN).psth(iS,:)] = spikeDensityFunction(nC(iN).rasters{iS},binMs,FS,binMs*4);
    end
    
end

%% Shuffle and combine neural responses ...forloop

% Permute order of neuron types
permTs = mod(randperm(3*nNeurons),3)+1;
iA = 1; iB = 1; iC = 1;
for i = 1:(3*nNeurons)
    if permTs(i) == 1
        allN(i).sdf = nA(iA).sdf;
        iA = iA + 1;
    elseif permTs(i) == 2
        allN(i).sdf = nB(iB).sdf;
        iB = iB + 1;
    elseif permTs(i) == 3
        allN(i).sdf = nC(iC).sdf;
        iC = iC + 1;
    end
end
% Permute all again (for fun!) and leave two out
allN = allN(randperm(numel(allN)-2));
clear iA iB iC i

%% Save model neurons and ancillary variables to current directory
save(fullfile(pwd,'model_neurons_output.mat'),'nA','nB','nC','stim','time','FS','binMs','-v7.3')
% Save shuffled neurons
save(fullfile(pwd,'blind_neurons.mat'),'allN','stim','time','FS','binMs','-v7.3')

%% Plot model output (raster, sdf, stimulus, pooled output...)
iN = 2;
iS = 1;
n = nC(iN);

figure('Color',[1 1 1]);
for i = 0:2
    iS = i*2+1;
    ax1 = subplot(3,3,1+i);
    [xp,yp] = plotSpikeRaster(~~n.rasters{iS},'PlotType','VertLine');
    title('Model Neuron Spiking')
    ylabel('Trial Number')
    xlabel('Bins (ms)')
    box off

    ax2 = subplot(3,3,4+i);
    [sdf,psth] = spikeDensityFunction(n.rasters{iS},binMs,FS,binMs*4);
    plot(sdf);
    ylabel('Spike Density')
    xlabel('Time (ms)')
    box off

    ax3 = subplot(3,3,7+i);
    plot(stim(iS,:));
    hold on
    plot(n.pools(iS,:)./max(n.pools(iS,:)));
    xlabel('Time (ms)')
    ylabel('a.u.')
    box off
    if i == 0
        legend('Stimulus','Pooled Filter Output')
    end
    linkaxes([ax1 ax2],'x')
end

% %%% Mind the return %%%
% return

%% Save a more simplified set of variables 
dsLen = 5000; % Length of appended response vectors
data = cell2mat(struct2cell(allN));
data = permute(data,[2 1 3]);
data = reshape(data,dsLen,[])';
stim = downsample(reshape(stim',[],1),binMs/(1000/FS))';
time = (1:dsLen)./1000;
save(fullfile(pwd,'nb204_pca','pca_data.mat'),'data','stim','time','-v7.3');