#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__)) + '/spec_common'
require 'bindata'

describe "lambdas with index" do
  before(:all) do
    eval <<-END
      class NestedLambdaWithIndex < BinData::MultiValue
        uint8 :a, :value => lambda { index * 10 }
      end
    END
  end

  it "should use index of containing array" do
    arr = BinData::Array.new(:type =>
                               [:uint8, { :value => lambda { index * 10 } }],
                             :initial_length => 3)
    arr.snapshot.should == [0, 10, 20]
  end

  it "should use index of nearest containing array" do
    arr = BinData::Array.new(:type => :nested_lambda_with_index,
                             :initial_length => 3)
    arr.snapshot.should == [{"a" => 0}, {"a" => 10}, {"a" => 20}]
  end

  it "should fail if there is no containing array" do
    obj = NestedLambdaWithIndex.new
    lambda { obj.a }.should raise_error(NoMethodError)
  end
end

describe "lambdas with parent" do
  it "should access immediate parent when no parent is specified" do
    class NestedLambdaWithoutParent < BinData::MultiValue
      int8 :a, :value => 5
      int8 :b, :value => lambda { a }
    end

    class TestLambdaWithoutParent < BinData::MultiValue
      int8   :a, :value => 3
      nested_lambda_without_parent :x
    end

    obj = TestLambdaWithoutParent.new
    obj.x.b.should == 5
  end

  it "should access parent's parent when parent is specified" do
    class NestedLambdaWithParent < BinData::MultiValue
      int8 :a, :value => 5
      int8 :b, :value => lambda { parent.a }
    end

    class TestLambdaWithParent < BinData::MultiValue
      int8   :a, :value => 3
      nested_lambda_with_parent :x
    end

    obj = TestLambdaWithParent.new
    obj.x.b.should == 3
  end
end

describe "MultiValues with choice field" do
  before(:all) do
    eval <<-END
      class TupleMultiValue < BinData::MultiValue
        uint8 :a, :value => 3
        uint8 :b, :value => 5
      end
    END
  end

  it "should treat choice object transparently " do
    class MultiWithChoiceField < BinData::MultiValue
      choice :x, :choices => [[:tuple_multi_value]], :selection => 0
    end
    obj = MultiWithChoiceField.new

    obj.x.a.should == 3
  end

  it "should treat nested choice object transparently " do
    class MultiWithNestedChoiceField < BinData::MultiValue
      choice :x, :choices => [
                    [:choice, {
                        :choices => [[:tuple_multi_value]],
                        :selection => 0}
                    ]
                 ],
                 :selection => 0
    end
    obj = MultiWithNestedChoiceField.new

    obj.x.a.should == 3
  end
end
