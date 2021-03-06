%##############################################################
% This script tries to use VQual Featues as utterance feature vector
%##############################################################
% clear all;
% clc;
%%
% load('featureVQtest.mat')
use_pca = 0;
pca_latent_knob = 0.99999;

% Define lists
allFiles = 'allFiles.txt';
trainList = 'train_read_trials.txt';  
testList = 'test_read_trials.txt';

tic
%
% Extract features

featureDict = containers.Map;
fid = fopen(allFiles);
myData = textscan(fid,'%s');
fclose(fid);
myFiles = myData{1};

featureTypeDict = containers.Map;

for cnt = 1:length(myFiles)
    feature_save_name = split(myFiles{cnt}, ".");
    feature_save_name = feature_save_name{1} + ".mat";
    ftr = load(feature_save_name);
    feature = [];
    fn = fieldnames(ftr);
    for i = 1:length(fn)
       if fn{i} == "epoch" 
           continue;
       end
       frame_cnt = 2000;
       if length(ftr.(fn{i})) ~= frame_cnt
           continue;
       end
       valid_index = ~isnan(ftr.(fn{i}));
       feature_temp = ftr.(fn{i});
       feature_temp = feature_temp( valid_index );
       if isempty(feature_temp)
           continue;
       end
       
       if ismember(fn{i}, keys(featureTypeDict))
           featureTypeDict(fn{i}) = featureTypeDict(fn{i}) + 1;
       else
           featureTypeDict(fn{i}) = 1;
       end
    end
end    

feature_types =  keys(featureTypeDict);
feature_count = 0;
for cnt = 1:length(feature_types)
    if featureTypeDict(feature_types{cnt}) < length(myFiles)
        feature_types{cnt} = [];
    else
        feature_count = feature_count + 1;
    end
end
valid_features = cell(feature_count, 1);
feature_count = 1;
for cnt = 1:length(feature_types)
    if ~isempty(feature_types{cnt})
        valid_features{feature_count} = feature_types{cnt};
        feature_count = feature_count + 1;
    end
end
feature_count = feature_count - 1;
% disp(valid_features);
self_defined_feature_set = {
    'A1'     ,...
    'A2'     ,...
    'A3'     ,...
    'CPP'    ,...
    'F2K'    ,...
    'H1'     ,...
    'H1A1c'  ,...
    'H1A2c'  ,...
    'H1A3c'  ,...
    'H1H2c'  ,...
    'H2'     ,...
    'H2H4c'  ,...
    'H2K'    ,...
    'H2KH5Kc',...
    'H4'     ,...
    'H42Kc'  ,...
    'H5K'    ,...
    'pB1'    ,...
    'pB2'    ,...
    'pB3'    ,...
    'pF0'    ,...
    'pF1'    ,...
    'pF2'    ,...
    'pF3'    ,...
    'SHR'    ,...
    'Energy' ,...
    'HNR05'  ,...
    'HNR15'  ,...
    'HNR25'  ,...
    'HNR35'  ,...
    'shrF0'  ,...
    'strF0'
};




for cnt = 1:length(myFiles)
    [snd,fs] = audioread(myFiles{cnt});
    
%     try
        feature_save_name = split(myFiles{cnt}, ".");
        feature_save_name = feature_save_name{1} + ".mat";
        ftr = load(feature_save_name);
        feature = [];
        fn = fieldnames(ftr);
        for i = 1:length(fn)
           if ismember(fn{i}, valid_features) && ismember(fn{i}, self_defined_feature_set)
               valid_index = ~isnan(ftr.(fn{i}));
               feature_temp = ftr.(fn{i});
               feature_temp = feature_temp( valid_index );
               feature = [feature mean(feature_temp)];
           end
        end
        featureDict(myFiles{cnt}) = feature;
%         if size(feature) ~= feature_count
%             disp("Invalid feature number!");
%         end
        
%     catch
%         disp(["No features for the file ", myFiles{cnt}]);
%     end
    
    if(mod(cnt,100)==0)
        disp(['Completed ',num2str(cnt),' of ',num2str(length(myFiles)),' files.']);
    end
end
% save('featureVQtest');

%%
old_dim = size(featureDict(myFiles{cnt}), 2);
new_dim = old_dim;
if use_pca
    fid = fopen(allFiles,'r');
    myData = textscan(fid,'%s');
    fclose(fid);
    fileList = myData{1};
    wholeFeatures = zeros(length(fileList), old_dim);

    for cnt = 1:length(fileList)
        wholeFeatures(cnt,:) = featureDict(fileList{cnt});
    end

    [coeff,score,latent] = pca(wholeFeatures);
    new_dim = sum(cumsum(latent)./sum(latent) < pca_latent_knob)+1;
    trans_mat = coeff(:,1:new_dim);

    % apply dimension reduction
    for cnt = 1:length(myFiles)
        featureDict(myFiles{cnt}) = featureDict(myFiles{cnt})*trans_mat;
    end
end
%%

% Train the classifier
fid = fopen(trainList,'r');
myData = textscan(fid,'%s %s %f');
fclose(fid);
fileList1 = myData{1};
fileList2 = myData{2};
trainLabels = myData{3};
trainFeatures = zeros(length(trainLabels), new_dim);
for cnt = 1:length(trainLabels)
    trainFeatures(cnt, :) = -abs(featureDict(fileList1{cnt})-featureDict(fileList2{cnt}));
end

Mdl = fitcknn(trainFeatures,trainLabels,'NumNeighbors',15000,'Standardize',1);

%%
% Test the classifier
fid = fopen(testList);
myData = textscan(fid,'%s %s %f');
fclose(fid);
fileList1 = myData{1};
fileList2 = myData{2};
testLabels = myData{3};
testFeatures = zeros(length(testLabels), new_dim);
for cnt = 1:length(testLabels)
    testFeatures(cnt, :) = -abs(featureDict(fileList1{cnt})-featureDict(fileList2{cnt}));
end

[~,prediction,~] = predict(Mdl,testFeatures);
testScores = (prediction(:,2)./(prediction(:,1)+1e-15));
[eer,~] = compute_eer(testScores, testLabels);
disp(['The EER is ',num2str(eer),'%.']);

toc
%%