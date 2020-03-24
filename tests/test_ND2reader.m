% NR = ND2reader('D:\Projects\nd2sdk-matlab\test.nd2');
% I = getImage(NR, 1000);


%% Test coords/seq index

NR = ND2reader('D:\Projects\2020Feb Photodamage\data\ChannelRed,Cy5,RFP_Seq0000.nd2');
index = getSeqIndexFromCoords(NR, [10 5]);  %-> This is M = 1, T = 11

I = getImage(NR, index);


attributes = fileGetAttributes(NR);
textInfo = fileGetTextInfo(NR);
exptInfo = fileGetExperiment(NR);

frameInfo = fileGetFrameMetadata(NR, 0);

metadataInfo = fileGetMetadata(NR);
