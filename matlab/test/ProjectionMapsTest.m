classdef ProjectionMapsTest < matlab.unittest.TestCase
    % ProjectionMapsTest - Tests for app-specific projection maps
    %
    % Verifies that the projection maps in shared/model-projection/ are
    % correctly formatted, can be loaded by the ProjectionEngine, and work
    % with actual PKPD.Analysis objects.
    
    properties
        Engine
        MapsPath
    end
    
    methods (TestClassSetup)
        function setupEngine(testCase)
            testCase.MapsPath = fullfile(fileparts(mfilename('fullpath')), ...
                '..', '..', 'shared', 'model-projection');
            testCase.Engine = appFramework.projection.ProjectionEngine(testCase.MapsPath);
        end
    end
    
    methods (Test)
        function testProjectionMapsExist(testCase)
            % Verify all expected projection map files exist
            expectedFiles = ["analysis.json", "model.json", "species.json", ...
                "parameter.json", "pkpd-parameter.json", "dose.json", "variant.json"];
            
            for fileName = expectedFiles
                filePath = fullfile(testCase.MapsPath, fileName);
                testCase.verifyTrue(isfile(filePath), ...
                    sprintf('Projection map file missing: %s', fileName));
            end
        end
        
        function testAllMapsLoaded(testCase)
            % Verify all projection maps were loaded successfully
            testCase.verifyTrue(testCase.Engine.hasMap('PKPD.Analysis'));
            testCase.verifyTrue(testCase.Engine.hasMap('SimBiology.Model'));
            testCase.verifyTrue(testCase.Engine.hasMap('SimBiology.Species'));
            testCase.verifyTrue(testCase.Engine.hasMap('SimBiology.Parameter'));
            testCase.verifyTrue(testCase.Engine.hasMap('PKPD.Parameter'));
            testCase.verifyTrue(testCase.Engine.hasMap('SimBiology.Dose'));
            testCase.verifyTrue(testCase.Engine.hasMap('SimBiology.Variant'));
        end
        
        function testAnalysisMapProperties(testCase)
            % Verify Analysis projection map has expected properties
            map = testCase.Engine.getMap('PKPD.Analysis');
            
            testCase.verifyEqual(map.MATLABClass, "PKPD.Analysis");
            testCase.verifyEqual(map.JSClass, "Analysis");
            
            propNames = map.getPropertyNames();
            expectedProps = ["ModelObj", "StartTime", "TimeStep", "StopTime", ...
                "FitFunctionName", "UseFitBounds", "FitErrorModel", ...
                "NumPopulationRuns", "ModelDocumentation", "SelectedSpecies", ...
                "SelectedParams", "SelectedDoses", "SelectedVariants"];
            
            for prop = expectedProps
                testCase.verifyTrue(any(propNames == prop), ...
                    sprintf('Analysis map missing property: %s', prop));
            end
        end
        
        function testModelMapProperties(testCase)
            % Verify SimBiology.Model projection map has expected properties
            map = testCase.Engine.getMap('SimBiology.Model');
            
            testCase.verifyEqual(map.MATLABClass, "SimBiology.Model");
            testCase.verifyEqual(map.JSClass, "SimBiologyModel");
            testCase.verifyEqual(map.ReferenceIDProperty, "SessionID");
            
            propNames = map.getPropertyNames();
            expectedProps = ["SessionID", "Name", "Species", "Parameters", "Doses", "Variants"];
            
            for prop = expectedProps
                testCase.verifyTrue(any(propNames == prop), ...
                    sprintf('Model map missing property: %s', prop));
            end
        end
        
        function testSpeciesMapReferenceID(testCase)
            % Verify Species map has correct ReferenceIDProperty for references
            map = testCase.Engine.getMap('SimBiology.Species');
            
            testCase.verifyEqual(map.ReferenceIDProperty, "SessionID");
        end
        
        function testAnalysisReferenceProperties(testCase)
            % Verify Analysis map correctly marks reference properties
            map = testCase.Engine.getMap('PKPD.Analysis');
            
            selectedSpeciesDef = map.getPropertyDefinition('SelectedSpecies');
            testCase.verifyTrue(selectedSpeciesDef.IsReference, ...
                'SelectedSpecies should be marked as reference');
            testCase.verifyTrue(selectedSpeciesDef.IsArray, ...
                'SelectedSpecies should be marked as array');
            
            selectedDosesDef = map.getPropertyDefinition('SelectedDoses');
            testCase.verifyTrue(selectedDosesDef.IsReference, ...
                'SelectedDoses should be marked as reference');
            
            selectedVariantsDef = map.getPropertyDefinition('SelectedVariants');
            testCase.verifyTrue(selectedVariantsDef.IsReference, ...
                'SelectedVariants should be marked as reference');
            
            modelObjDef = map.getPropertyDefinition('ModelObj');
            testCase.verifyFalse(modelObjDef.IsReference, ...
                'ModelObj should NOT be marked as reference (owned)');
        end
        
        function testAnalysisReadOnlyProperties(testCase)
            % Verify Analysis map correctly marks read-only properties
            map = testCase.Engine.getMap('PKPD.Analysis');
            
            modelObjDef = map.getPropertyDefinition('ModelObj');
            testCase.verifyTrue(modelObjDef.ReadOnly, ...
                'ModelObj should be marked as ReadOnly');
            
            startTimeDef = map.getPropertyDefinition('StartTime');
            testCase.verifyFalse(startTimeDef.ReadOnly, ...
                'StartTime should NOT be marked as ReadOnly');
        end
        
        function testPKPDParameterMap(testCase)
            % Verify PKPD.Parameter projection map is distinct from SimBiology.Parameter
            pkpdMap = testCase.Engine.getMap('PKPD.Parameter');
            sbMap = testCase.Engine.getMap('SimBiology.Parameter');
            
            testCase.verifyNotEqual(pkpdMap.MATLABClass, sbMap.MATLABClass);
            testCase.verifyEqual(pkpdMap.MATLABClass, "PKPD.Parameter");
            testCase.verifyEqual(sbMap.MATLABClass, "SimBiology.Parameter");
        end
        
        function testNestedTypeResolution(testCase)
            % Verify engine can resolve nested types from Analysis
            map = testCase.Engine.getMap('PKPD.Analysis');
            
            modelObjDef = map.getPropertyDefinition('ModelObj');
            nestedMap = map.getNestedMap(modelObjDef.Type);
            
            testCase.verifyEqual(nestedMap.MATLABClass, "SimBiology.Model");
        end
    end
    
    methods (Test, TestTags = {'Integration'})
        function testToJSONWithAnalysis(testCase)
            % Integration test: convert actual PKPD.Analysis to JSON
            % This test requires SimBiology toolbox
            
            analysis = PKPD.Analysis;
            analysis.StartTime = 0;
            analysis.StopTime = 100;
            analysis.TimeStep = 1;
            
            jsonStruct = testCase.Engine.toJSON(analysis);
            
            testCase.verifyEqual(jsonStruct.StartTime, 0);
            testCase.verifyEqual(jsonStruct.StopTime, 100);
            testCase.verifyEqual(jsonStruct.TimeStep, 1);
        end
        
        function testToJSONWithModel(testCase)
            % Integration test: Analysis with imported model
            
            testDataFolder = fullfile(fileparts(mfilename('fullpath')), 'data');
            sbprojFile = fullfile(testDataFolder, 'lotkaWithDosesAndVariants.sbproj');
            
            if ~isfile(sbprojFile)
                testCase.assumeFail('Test data file not found');
            end
            
            analysis = PKPD.Analysis;
            projStruct = sbioloadproject(sbprojFile);
            varNames = fieldnames(projStruct);
            for i = 1:numel(varNames)
                if isa(projStruct.(varNames{i}), 'SimBiology.Model')
                    analysis.importModel(sbprojFile, projStruct.(varNames{i}).Name);
                    break;
                end
            end
            
            jsonStruct = testCase.Engine.toJSON(analysis);
            
            testCase.verifyTrue(isfield(jsonStruct, 'ModelObj'));
            testCase.verifyTrue(isstruct(jsonStruct.ModelObj));
            testCase.verifyTrue(isfield(jsonStruct.ModelObj, 'Name'));
            testCase.verifyTrue(isfield(jsonStruct.ModelObj, 'Species'));
        end
    end
end
