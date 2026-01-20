classdef ControllerTest < matlab.unittest.TestCase
    % ControllerTest - Unit tests for gPKPDSimConfigurationTool.Controller
    
    properties
        Controller
        TestDataFolder
        TempFolder
    end
    
    methods (TestMethodSetup)
        function setupTest(testCase)
            testCase.TestDataFolder = fullfile(fileparts(mfilename('fullpath')), 'data');
            testCase.TempFolder = tempname;
            mkdir(testCase.TempFolder);
            testCase.Controller = gPKPDSimConfigurationTool.Controller();
        end
    end
    
    methods (TestMethodTeardown)
        function teardownTest(testCase)
            if isfolder(testCase.TempFolder)
                rmdir(testCase.TempFolder, 's');
            end
        end
    end
    
    methods (Test)
        function testConstructor(testCase)
            % Test that controller initializes correctly
            testCase.verifyNotEmpty(testCase.Controller.ProjectionEngine);
            testCase.verifyEqual(testCase.Controller.SourceFilePath, "");
        end
        
        function testLoadFromAnalysisFile(testCase)
            % Test loading Analysis from .mat file via public API
            matFile = fullfile(testCase.TestDataFolder, 'CaseStudy1', ...
                'casestudy1_TwoCompPK_final.mat');
            
            analysis = testCase.Controller.loadFromAnalysisFile(matFile);
            
            testCase.verifyClass(analysis, 'PKPD.Analysis');
            testCase.verifyEqual(testCase.Controller.SourceFilePath, string(matFile));
        end
        
        function testLoadFromAnalysisFileNotFound(testCase)
            % Test error when file not found
            testCase.verifyError(...
                @() testCase.Controller.loadFromAnalysisFile('/nonexistent/file.mat'), ...
                'gPKPDSimConfigurationTool:FileNotFound');
        end
        
        function testLoadFromProject(testCase)
            % Test creating Analysis from .sbproj file via public API
            sbprojFile = fullfile(testCase.TestDataFolder, ...
                'lotkaWithDosesAndVariants.sbproj');
            
            modelNames = testCase.Controller.queryProjectForModels(sbprojFile);
            testCase.verifyNotEmpty(modelNames);
            
            % filePath first, modelName second (both optional)
            analysis = testCase.Controller.loadFromProject(sbprojFile, modelNames(1));
            
            testCase.verifyClass(analysis, 'PKPD.Analysis');
            testCase.verifyEqual(testCase.Controller.SourceFilePath, string(sbprojFile));
        end
        
        function testLoadFromProjectAutoDetectModel(testCase)
            % Test that loadFromProject auto-detects model name for single-model projects
            sbprojFile = fullfile(testCase.TestDataFolder, ...
                'lotkaWithDosesAndVariants.sbproj');
            
            modelNames = testCase.Controller.queryProjectForModels(sbprojFile);
            
            if numel(modelNames) == 1
                % If project has only one model, modelName is optional
                analysis = testCase.Controller.loadFromProject(sbprojFile);
                testCase.verifyClass(analysis, 'PKPD.Analysis');
            else
                % Multi-model project - should error without modelName
                testCase.verifyError(...
                    @() testCase.Controller.loadFromProject(sbprojFile), ...
                    'gPKPDSimConfigurationTool:MultipleModels');
            end
        end
        
        function testQueryProjectForModels(testCase)
            % Test querying .sbproj file for model names
            sbprojFile = fullfile(testCase.TestDataFolder, ...
                'lotkaWithDosesAndVariants.sbproj');
            
            modelNames = testCase.Controller.queryProjectForModels(sbprojFile);
            
            testCase.verifyClass(modelNames, 'string');
            testCase.verifyNotEmpty(modelNames);
        end
        
        function testSaveAnalysis(testCase)
            % Test saving Analysis to .mat file
            matFile = fullfile(testCase.TestDataFolder, 'CaseStudy1', ...
                'casestudy1_TwoCompPK_final.mat');
            testCase.Controller.loadFromAnalysisFile(matFile);
            
            saveFile = fullfile(testCase.TempFolder, 'test_save.mat');
            testCase.Controller.save(saveFile);
            
            testCase.verifyTrue(isfile(saveFile));
            testCase.verifyEqual(testCase.Controller.SourceFilePath, string(saveFile));
            
            saved = load(saveFile);
            testCase.verifyTrue(isfield(saved, 'Analysis'));
            testCase.verifyClass(saved.Analysis, 'PKPD.Analysis');
        end
        
        function testSaveAddsMatExtension(testCase)
            % Test that save adds .mat extension if missing
            matFile = fullfile(testCase.TestDataFolder, 'CaseStudy1', ...
                'casestudy1_TwoCompPK_final.mat');
            testCase.Controller.loadFromAnalysisFile(matFile);
            
            saveFile = fullfile(testCase.TempFolder, 'test_no_ext');
            testCase.Controller.save(saveFile);
            
            testCase.verifyTrue(isfile(saveFile + ".mat"));
        end
        
        function testAnalysisPropertiesAccessible(testCase)
            % Test that Analysis properties are accessible after load
            matFile = fullfile(testCase.TestDataFolder, 'CaseStudy1', ...
                'casestudy1_TwoCompPK_final.mat');
            testCase.Controller.loadFromAnalysisFile(matFile);
            
            testCase.verifyNotEmpty(testCase.Controller.RootObject);
            testCase.verifyClass(testCase.Controller.RootObject.StartTime, 'double');
            testCase.verifyClass(testCase.Controller.RootObject.StopTime, 'double');
        end
        
        function testMultipleCaseStudies(testCase)
            % Test loading multiple case studies
            caseStudies = {'CaseStudy1/casestudy1_TwoCompPK_final.mat', ...
                           'CaseStudy2/casestudy2_TMDD_final.mat'};
            
            for i = 1:numel(caseStudies)
                matFile = fullfile(testCase.TestDataFolder, caseStudies{i});
                if isfile(matFile)
                    testCase.Controller.loadFromAnalysisFile(matFile);
                    testCase.verifyClass(testCase.Controller.RootObject, 'PKPD.Analysis');
                end
            end
        end
    end
end
