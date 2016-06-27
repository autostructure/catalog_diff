# File:  tc_simple_number2.rb

require_relative '../lib/puppet/catalog-diff/catalog'
require 'test/unit'

class TestCatalog < Test::Unit::TestCase
  TAGS1 = [
    'settings',
    'multi_param_class',
    'class',
  ]

  NAME1 = 'elmo.mydomain.com'
  VERSION1 = 1_377_473_054
  CODE_ID1 = nil
  CATALOG_UUID1 = '827a74c8-cf98-44da-9ff7-18c5e4bee41e'
  CATALOG_FORMAT1 = 1
  ENVIRONMENT1 = 'production'
  RESOURCES1 =  [
    {
      'type' => 'Stage',
      'title' => 'main',
      'tags' => [
        'stage',
      ],
      'exported' => false,
      'parameters' => {
        'name' => 'main',
      },
    },
    {
      'type' => 'Class',
      'title' => 'Settings',
      'tags' => [
        'class',
        'settings',
      ],
      'exported' => false,
    },
    {
      'type' => 'Class',
      'title' => 'main',
      'tags' => [
        'class',
      ],
      'exported' => false,
      'parameters' => {
        'name' => 'main',
      },
    },
    {
      'type' => 'Class',
      'title' => 'Multi_param_class',
      'tags' => [
        'class',
        'multi_param_class',
      ],
      'line' => 10,
      'exported' => false,
      'parameters' => {
        'one' => 'hello',
        'two' => 'world',
      },
    },
    {
      'type' => 'Notify',
      'title' => 'foo',
      'tags' => [
        'notify',
        'foo',
        'class',
        'multi_param_class',
      ],
      'line' => 4,
      'exported' => false,
      'parameters' => {
        'message' => 'One is hello, two is world',
      },
    },
  ]

  EDGES1 = [
    {
      'source' => 'Stage[main]',
      'target' => 'Class[Settings]',
    },
    {
      'source' => 'Stage[main]',
      'target' => 'Class[main]',
    },
    {
      'source' => 'Stage[main]',
      'target' => 'Class[Multi_param_class]',
    },
    {
      'source' => 'Class[Multi_param_class]',
      'target' => 'Notify[foo]',
    },
  ]

  CLASSES1 = [
    'settings',
    'multi_param_class',
  ]

  CLASSES2 = [
    'settings2',
    'multi_param_class2',
  ]

  def test_simple

    catalog1 = Puppet::CatalogDiff::Catalog.new(
      TAGS1,
      NAME1,
      VERSION1,
      CODE_ID1,
      CATALOG_UUID1,
      CATALOG_FORMAT1,
      ENVIRONMENT1,
      RESOURCES1,
      EDGES1,
      CLASSES1
    )

    catalog2 = Puppet::CatalogDiff::Catalog.new(
      TAGS1,
      NAME1,
      VERSION1,
      CODE_ID1,
      CATALOG_UUID1,
      CATALOG_FORMAT1,
      ENVIRONMENT1,
      RESOURCES1,
      EDGES1,
      CLASSES1
    )

    catalog3 = Puppet::CatalogDiff::Catalog.new(
      TAGS1,
      NAME1,
      VERSION1,
      CODE_ID1,
      CATALOG_UUID1,
      CATALOG_FORMAT1,
      ENVIRONMENT1,
      RESOURCES1,
      EDGES1,
      CLASSES2
    )

    assert_equal(catalog1, catalog2)
    assert_not_equal(catalog1, catalog3)

    assert_nothing_raised(RuntimeError) { JSON.parse(catalog1.to_json)}

    assert_equal([catalog1, catalog2, catalog3].uniq, [catalog1, catalog3])
  end

  # def test_typecheck
  #   assert_raise(RuntimeError) { SimpleNumber.new('a') }
  # end
#
  # def test_failure
  #   assert_equal(3, SimpleNumber.new(2).add(2), "Adding doesn't work")
  # end
end
