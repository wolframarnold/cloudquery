require 'rubygems'
require 'cloudquery'
require 'time'
include Cloudquery

def assert(*msg)
    raise "Assertion failed! #{msg}" unless yield if $DEBUG
end
def datemillis(d)
    return (1000 * Time.parse(d).to_i)
end

def test(account='test_client@xoopit.com', secret='lSp7nnziZJMvl9Bw72Gyy4')
    $DEBUG = true
    c = Client.new(:account => account, :secret => secret)

    # get account
    r = c.get_account()
    print JSON.generate(r);
    a = r['result']
    assert( 'non-200: ' + JSON.generate(r) ) { r['STATUS'] == 200 }
    assert( 'account does not match: ' + JSON.generate(a) ) { a['name'] == account }

    print "hello\n"

    # update account
    r = c.update_account( a )
    assert( 'non-200: ' + JSON.generate(r) ) { r['STATUS'] == 200 }
    assert( 'no result: ' + JSON.generate(r) ) { r['result'] != nil }

    # schema
    r = c.add_schema(File.open('test_schema.xml'))
    print JSON.generate(r) + "\n"
    r = c.delete_schema('cq.test.contact')
    print JSON.generate(r) + "\n"
    r = c.add_schema(File.open('test_schema.xml'))
    print JSON.generate(r) + "\n"
    assert( 'non-201: ' + JSON.generate(r) ) { r['STATUS'] == 201 }
    assert( 'no result: ' + JSON.generate(r) ) { r['result'] != nil }

    # index
    r = c.add_indexes('test')
    r = c.delete_indexes('test')
    assert( 'non-200/404: ' + JSON.generate(r) ) { (r['STATUS'] == 200 or r['STATUS'] == 404) }

    r = c.add_indexes('test')
    assert( 'non-201: ' + JSON.generate(r) ) { (r['STATUS'] == 201) }
    iids = r['result']

    r = c.get_indexes()
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'iids dont match: ' + JSON.generate(r) + ' ' + JSON.generate(iids) ) { (r['result'].index(iids[0]) != -1) }

    # add some documents
    dox = []
    dox.push({
        'cq.test.contact.name'=>'Steve Rogers',
        'cq.test.contact.email'=>['steve.rogers@example.com','captain.america@marvel.com'],
        'cq.test.contact.telephone'=>['555-555-5555','123-456-6789'],
        'cq.test.contact.address'=>['Lower East Side, NY NY'],
        'cq.test.contact.birthday'=>datemillis('July 4, 1917'),
        'cq.test.contact.note'=>'Captain America!',
        })
    dox.push({
        'cq.test.contact.name'=>'Clark Kent',
        'cq.test.contact.email'=>['clark.kent@example.com','superman@dc.com'],
        'cq.test.contact.telephone'=>['555-123-1234','555-456-6789'],
        'cq.test.contact.address'=>[
            '344 Clinton St., Apt. #3B, Metropolis',
            'The Fortess of Solitude, North Pole',
        ],
        'cq.test.contact.birthday'=>datemillis('June 18, 1938'),
        'cq.test.contact.note'=>'Superhuman strength, speed, stamina, durability,' \
            ' senses, intelligence, regeneration, and longevity;' \
            ' super breath, heat vision, x-ray vision and flight.' \
            ' Member of the justice league.',
    })
    dox.push({
        'cq.test.contact.name'=>'Bruce Wayne',
        'cq.test.contact.email'=>['bruce.wayne@example.com','batman@dc.com'],
        'cq.test.contact.telephone'=>['555-123-6666','555-456-6666'],
        'cq.test.contact.address'=>[
            '1007 Mountain Drive, Gotham',
            'The Batcave, Gotham',
        ],
        'cq.test.contact.birthday'=>datemillis('February 19, 1939'),
        'cq.test.contact.note'=>'Sidekick is Robin. Has problems with the Joker.' \
            ' Member of the justice league.',
    })

    # add 1st copy
    r = c.add_documents('test', dox, 'cq.test.contact')
    assert( 'non-201: ' + JSON.generate(r) ) { (r['STATUS'] == 201) }
    assert( 'no result: ' + JSON.generate(r) ) { (r['result'] != nil) }
    assert( 'wrong number of results: ' + JSON.generate(r) ) { (r['size'] == 3) }

    # test provided hashable doc id
    dox.each { |d|
        d['#.#'] = d['cq.test.contact.name']
    }

    # add 2nd copy
    r = c.add_documents('test', dox, 'cq.test.contact')
    assert( 'non-201: ' + JSON.generate(r) ) { (r['STATUS'] == 201) }
    assert( 'no result: ' + JSON.generate(r) ) { (r['result'] != nil) }
    assert( 'wrong number of results: ' + JSON.generate(r) ) { (r['size'] == 3) }

    # test provided actual doc id
    dox.each { |d|
        d['#.#'] = x64enc.enc('test' + d['cq.test.contact.name'])
    }

    # add 3rd copy
    r = c.add_documents('test', dox, 'cq.test.contact')
    assert( 'non-201: ' + JSON.generate(r) ) { (r['STATUS'] == 201) }
    assert( 'no result: ' + JSON.generate(r) ) { (r['result'] != nil) }
    assert( 'wrong number of results: ' + JSON.generate(r) ) { (r['size'] == 3) }
    docid = r['result'][0]

    # explict by id
    r = c.get_documents('test', 'cq.test.contact', '#.#:' + docid)
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'wrong id: ' + JSON.generate(r) + ' ' + docid ) { (r['result'][0]['#.#'] == docid) }
    assert( 'wrong name: ' + JSON.generate(r) ) { (r['result'][0]['cq.test.contact.name'] == dox[0]['cq.test.contact.name']) }
    assert( 'wrong number of results: ' + JSON.generate(r) ) { (r['size'] == 1) }

    # implicit by id
    # r = c.get_documents('test', 'cq.test.contact', docid)
    # assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    # assert( 'wrong id: ' + JSON.generate(r) + ' ' + docid ) { (r['result'][0]['#.#'] == docid) }
    # assert( 'wrong name: ' + JSON.generate(r) ) { (r['result'][0]['cq.test.contact.name'] != dox[0]['cq.test.contact.name']) }
    # assert( 'wrong number of results: ' + JSON.generate(r) ) { (r['size'] == 1) }

    r1 = c.get_documents('test','cq.test.contact', '*')
    r2 = c.get_documents('*','cq.test.contact', '*')
    r3 = c.get_documents('*','*', '*')
    assert( 'results differ 1,2: ' + JSON.generate(r1) + ' ' + JSON.generate(r2) ) { (JSON.generate(r1) == JSON.generate(r2)) }
    assert( "results differ 2,3: #{r2['result'].size} vs #{r3['result'].size}, #{JSON.generate(r2)} vs #{JSON.generate(r3)}" ) { (JSON.generate(r2) == JSON.generate(r3)) }

    # field select and sort
    #r = c.get_documents('test', 'cq.test.contact', '*', 'cq.test.*', ['^','#.#'])
    r = c.get_documents('test', 'cq.test.contact', '*', 'cq.test.*', ['^'])
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'less stuff' ) { (r['result'].size == r1['result'].size) }

    # modify
    r = c.modify_documents('test','cq.test.contact', 'name:Steve', {'cq.test.contact.name'=> 'Jimmy Rogers'})
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'should be 3 copies: %d' % r['result'].size ) { (r['result'].size == 3) }
    # verify change
    r = c.get_documents('test','cq.test.contact', 'name:Steve')
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'should be 0 doc ids: %d' % r['result'].size ) { (r['result'].size == 0) }
    r = c.get_documents('test','cq.test.contact', 'name:Jimmy')
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'should be 3 doc ids: %d' % r['result'].size ) { (r['result'].size == 3) }
    docs = r['result']

    # change back
    docs.each { |d|
        d['cq.test.contact.name'] = 'Steve Rogers'
    }
    r = c.update_documents('test', docs)
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'should be 3 doc ids: %d' % r['result'].size ) { (r['result'].size == 3) }
    # verify change
    r = c.get_documents('test','cq.test.contact', 'name:Steve')
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'should be 3 doc ids: %d' % r['result'].size ) { (r['result'].size == 3) }
    r = c.get_documents('test','cq.test.contact', 'name:Jimmy')
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'should be 0 doc ids: %d' % r['result'].size ) { (r['result'].size == 0) }

    # delete
    r = c.delete_documents('test','cq.test.contact', 'name:Steve', sort='-#.createdTime', limit=2)
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'should be 2 doc ids: %d' % r['result'].size ) { (r['result'].size == 2) }

    r = c.count_documents('test', 'cq.test.contact', 'name:Steve')
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'should be 1 left: %d' % r['result'].size ) { (r['result'] == 1) }

    # put back
    r = c.update_documents('test', docs)
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }

    r = c.count_documents('test', 'cq.test.contact', 'name:Steve')
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'should be 3: %d' % r['result'].size ) { (r['result'] == 3) }


    # ask for short fields
    #r = c.get_documents('test', 'cq.test.contact', '*', 'cq.test.*', ['^','#.#'], fieldmode='short')
    r = c.get_documents('test', 'cq.test.contact', '*', 'cq.test.*', ['^'], fieldmode='short')
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    r['result'].each { |d|
        d.each { |k,v|
            assert( 'keys should be short, no dots' ) { (k.find('.') == -1) }
            assert( 'keys should be short' ) { (k.startswith('cq.test') == False) }
        }
    }

    # upload short fields
    dox = []
    dox.push({
        'name'=>'Steve Rogers',
        'email'=>['steve.rogers@example.com','captain.america@marvel.com'],
        'telephone'=>['555-555-5555','123-456-6789'],
        'address'=>['Lower East Side, NY NY'],
        'birthday'=>datemillis('July 4, 1917'),
        'note'=>'Captain America!',
        })
    dox.push({
        'name'=>'Clark Kent',
        'email'=>['clark.kent@example.com','superman@dc.com'],
        'telephone'=>['555-123-1234','555-456-6789'],
        'address'=>[
            '344 Clinton St., Apt. #3B, Metropolis',
            'The Fortess of Solitude, North Pole',
        ],
        'birthday'=>datemillis('June 18, 1938'),
        'note'=>'Superhuman strength, speed, stamina, durability,' \
            ' senses, intelligence, regeneration, and longevity;' \
            ' super breath, heat vision, x-ray vision and flight.' \
            ' Member of the justice league.',
    })
    dox.push({
        'name'=>'Bruce Wayne',
        'email'=>['bruce.wayne@example.com','batman@dc.com'],
        'telephone'=>['555-123-6666','555-456-6666'],
        'address'=>[
            '1007 Mountain Drive, Gotham',
            'The Batcave, Gotham',
        ],
        'birthday'=>datemillis('February 19, 1939'),
        'note'=>'Sidekick is Robin. Has problems with the Joker. Member of the justice league.',
    })
    
    # add 4th copy
    r = c.add_documents('test', dox, 'cq.test.contact')
    assert( 'non-201: ' + JSON.generate(r) ) { (r['STATUS'] == 201) }
    assert( 'no result: ' + JSON.generate(r) ) { (r['result'] != nil) }
    assert( 'wrong number of results: ' + JSON.generate(r) ) { (r['size'] == 3) }

    # test provided hashable doc id
    dox.each { |d|
        d['#.#'] = d['name']
    }
    
    # overwrite
    count = c.count_documents('test','*','*')['result']
    r = c.add_documents('test', dox, 'cq.test.contact')
    assert( 'non-201: ' + JSON.generate(r) ) { (r['STATUS'] == 201) }
    assert( 'no result: ' + JSON.generate(r) ) { (r['result'] != nil) }
    assert( 'wrong number of results: ' + JSON.generate(r) ) { (r['size'] == 3) }

    assert (count == c.count_documents('test','*','*')['result']), 'adding documents changed overall count'


    # delete the schema and all docs with it
    r = c.delete_schema('cq.test.contact', True)
    assert( 'non-200: ' + JSON.generate(r) ) { (r['STATUS'] == 200) }
    assert( 'no result: ' + JSON.generate(r) ) { (r['result'] != nil) }

    count = c.count_documents('test','*','*')['result']
    assert( 'should have deleted all documents' ) { (count == 0) }

end

test()
