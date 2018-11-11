% Clear Command Window and Workspace
clear;
clc;

categories = {'dogs','cats'};

rootFolder = 'dataset/train_set';
imds = imageDatastore(fullfile(rootFolder, categories), ...
    'LabelSource', 'foldernames');
imds.ReadFcn = @readFunctionTrain;

[imdsTrain,imdsValidation] = splitEachLabel(imds,0.8,'randomized');

%%
varSize = 32;
conv1 = convolution2dLayer(5,varSize,'Padding',2,'BiasLearnRateFactor',2);
conv1.Weights = gpuArray(single(randn([5 5 3 varSize])*0.0001));
fc1 = fullyConnectedLayer(64,'BiasLearnRateFactor',2);
fc1.Weights = gpuArray(single(randn([64 576])*0.1));
fc2 = fullyConnectedLayer(2,'BiasLearnRateFactor',2);
fc2.Weights = gpuArray(single(randn([2 64])*0.1));

augmenter = imageDataAugmenter( ...
    'RandXReflection', true(1), ...
    'RandXScale',[0.5 2], ...
    'RandYShear', [0 15]);

imageSize = [32 32 1];
auimdsTrain = augmentedImageDatastore(imageSize,imdsTrain,'DataAugmentation',augmenter);
ims = auimdsTrain.preview();
montage(ims{:,1})

layers = [
    imageInputLayer([varSize varSize 3]);
    conv1;
    maxPooling2dLayer(3,'Stride',2);
    reluLayer();
    convolution2dLayer(5,48,'Padding',2,'BiasLearnRateFactor',2);
    reluLayer();
    averagePooling2dLayer(3,'Stride',2);
    convolution2dLayer(5,64,'Padding',2,'BiasLearnRateFactor',2);
    reluLayer();
    averagePooling2dLayer(3,'Stride',2);
    fc1;
    reluLayer();
    fc2;
    softmaxLayer();
    classificationLayer()];

opts = trainingOptions('sgdm', ...
    'InitialLearnRate', 0.0001, ...
    'MaxEpochs', 5, ...
    'Shuffle','every-epoch', ...
    'MiniBatchSize', 10, ...
    'ValidationData',imdsValidation, ...
    'ValidationFrequency',400, ...
    'Verbose', true, ...
    'VerboseFrequency', 400, ...
    'Plots','training-progress', ...
    'ExecutionEnvironment', 'auto');

[net, info] = trainNetwork(auimdsTrain, layers, opts);

augment_mynet = net;
save augment_mynet

%%
load augment_mynet;
analyzeNetwork(augment_mynet)

%%
load augment_mynet;
augment_mynet.Layers
%%
load augment_mynet;
rootFolder2 = 'dataset/test_set';
imdsTest = imageDatastore(fullfile(rootFolder2, categories), ...
    'LabelSource', 'foldernames');
imdsTest.ReadFcn = @readFunctionTrain;

labels = classify(augment_mynet, imdsTest);
accuracy = mean(labels == imdsTest.Labels)

figure
plotconfusion(imdsTest.Labels, labels)

%%
%Display some testing images
for i = 1:10
    ii = randi(2000);
    im = imread(imdsTest.Files{ii});
    figure
    imshow(im);
    if labels(ii) == imdsTest.Labels(ii)
       colorText = 'g'; 
    else
        colorText = 'r';
    end
    title(char(labels(ii)),'Color',colorText);
end
