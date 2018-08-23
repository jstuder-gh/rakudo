my class X::Hash::Store::OddNumber { ... }

my class Map does Iterable does Associative { # declared in BOOTSTRAP
    # my class Map is Iterable is Cool
    #   has Mu $!storage;

    multi method WHICH(Map:D:) {
        nqp::box_s(
          nqp::concat(
            nqp::if(
              nqp::eqaddr(self.WHAT,Map),
              'Map|',
              nqp::concat(self.^name,'|')
            ),
            nqp::sha1(
              nqp::join(
                '|',
                nqp::stmts(  # cannot use native str arrays early in setting
                  (my $keys := nqp::list_s),
                  (my \iter := nqp::iterator($!storage)),
                  nqp::while(
                    iter,
                    nqp::push_s($keys,nqp::iterkey_s(nqp::shift(iter)))
                  ),
                  (my $sorted   := Rakudo::Sorting.MERGESORT-str($keys)),
                  (my int $i     = -1),
                  (my int $elems = nqp::elems($sorted)),
                  (my $strings  := nqp::list_s),
                  nqp::while(
                    nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                    nqp::stmts(
                      (my $key := nqp::atpos_s($sorted,$i)),
                      nqp::push_s($strings,$key),
                      nqp::push_s($strings,nqp::atkey($!storage,$key).perl)
                    )
                  ),
                  $strings
                )
              )
            )
          ),
          ValueObjAt
        )
    }
    method new(*@args) {
        @args
          ?? nqp::create(self).STORE(@args, :initialize)
          !! nqp::create(self)
    }

    multi method Map(Map:) { self }

    multi method Hash(Map:U:) { Hash }
    multi method Hash(Map:D:) {
        if nqp::elems($!storage) {
            my \hash       := nqp::create(Hash);
            my \storage    := nqp::bindattr(hash,Map,'$!storage',nqp::hash);
            my \descriptor := nqp::getcurhllsym('default_cont_spec');
            my \iter       := nqp::iterator(nqp::getattr(self,Map,'$!storage'));
            nqp::while(
              iter,
              nqp::bindkey(
                storage,
                nqp::iterkey_s(nqp::shift(iter)),
                nqp::p6scalarwithvalue(
                  descriptor, nqp::decont(nqp::iterval(iter)))
              )
            );
            hash
        }
        else {
            nqp::create(Hash)
        }
    }

    multi method Bool(Map:D:) {
        nqp::p6bool(nqp::elems($!storage));
    }
    method elems(Map:D:) {
        nqp::p6box_i(nqp::elems($!storage));
    }
    multi method Int(Map:D:)     { self.elems }
    multi method Numeric(Map:D:) { self.elems }
    multi method Str(Map:D:)     { self.sort.join("\n") }

    method IterationBuffer() {
        nqp::stmts(
          (my \buffer := nqp::create(IterationBuffer)),
          nqp::if(
            nqp::elems($!storage),
            nqp::stmts(
              (my \iterator := nqp::iterator($!storage)),
              nqp::setelems(buffer,nqp::elems($!storage)),
              (my int $i = -1),
              nqp::while(
                iterator,
                nqp::bindpos(buffer,($i = nqp::add_i($i,1)),
                  Pair.new(
                    nqp::iterkey_s(nqp::shift(iterator)),
                    nqp::iterval(iterator)
                  )
                )
              )
            )
          ),
          buffer
        )
    }

    method List() {
        nqp::p6bindattrinvres(
          nqp::create(List),List,'$!reified',self.IterationBuffer)
    }

    multi method head(Map:D:) {
        nqp::if(
          nqp::elems($!storage),
          Pair.new(
            nqp::iterkey_s(
              nqp::shift(my \iterator := nqp::iterator($!storage))
            ),
            nqp::iterval(iterator)
          ),
          Nil
        )
    }

    multi method sort(Map:D:) {
        Seq.new(
          Rakudo::Iterator.IterationBuffer(
            Rakudo::Sorting.MERGESORT-REIFIED-LIST-AS(
              self.IterationBuffer,
              { nqp::getattr(nqp::decont($^a),Pair,'$!key') }
            )
          )
        )
    }

    multi method ACCEPTS(Map:D: Any $topic) {
        self.EXISTS-KEY($topic.any);
    }

    multi method ACCEPTS(Map:D: Cool:D $topic) {
        self.EXISTS-KEY($topic);
    }

    multi method ACCEPTS(Map:D: Positional $topic) {
        self.EXISTS-KEY($topic.any);
    }

    multi method ACCEPTS(Map:D: Regex $topic) {
        so self.keys.any.match($topic);
    }

    multi method ACCEPTS(Map:D: Map:D \m --> Bool) {
        try {self eqv m} // False;
    }

    multi method EXISTS-KEY(Map:D: Str:D \key) {
        nqp::p6bool(nqp::existskey($!storage,key))
    }
    multi method EXISTS-KEY(Map:D: \key) {
        nqp::p6bool(nqp::existskey($!storage,key.Str))
    }

    multi method gist(Map:D:) {
        self.^name ~ '.new((' ~ self.sort.map({
            state $i = 0;
            ++$i == 101 ?? '...'
                !! $i == 102 ?? last()
                    !! .gist
        }).join(', ') ~ '))'
    }

    multi method perl(Map:D \SELF:) {
        my $p = self.^name ~ '.new((' ~ self.sort.map({.perl}).join(',') ~ '))';
        nqp::iscont(SELF) ?? '$(' ~ $p ~ ')' !! $p
    }

    my class Iterate does Rakudo::Iterator::Mappy {
        method pull-one() {
            nqp::if(
              $!iter,
              nqp::stmts(
                nqp::shift($!iter),
                Pair.new(nqp::iterkey_s($!iter), nqp::iterval($!iter))
              ),
              IterationEnd
            )
        }
        method push-all($target --> IterationEnd) {
            nqp::while(
              $!iter,
              nqp::stmts(  # doesn't sink
                 nqp::shift($!iter),
                 $target.push(
                   Pair.new(nqp::iterkey_s($!iter), nqp::iterval($!iter)))
              )
            )
        }
    }
    method iterator(Map:D:) { Iterate.new(self) }

    method list(Map:D:) {
        nqp::p6bindattrinvres(
          nqp::create(List),List,'$!reified',self.IterationBuffer)
    }
    multi method pairs(Map:D:) { Seq.new(self.iterator) }
    multi method keys(Map:D:) { Seq.new(Rakudo::Iterator.Mappy-keys(self)) }
    multi method values(Map:D:) { Seq.new(Rakudo::Iterator.Mappy-values(self)) }

    my class KV does Rakudo::Iterator::Mappy {
        has int $!on-value;

        method pull-one() is raw {
            nqp::if(
              $!on-value,
              nqp::stmts(
                ($!on-value = 0),
                nqp::iterval($!iter)
              ),
              nqp::if(
                $!iter,
                nqp::stmts(
                  ($!on-value = 1),
                  nqp::iterkey_s(nqp::shift($!iter))
                ),
                IterationEnd
              )
            )
        }
        method skip-one() {
            nqp::if(
              $!on-value,
              nqp::not_i($!on-value = 0), # skipped a value
              nqp::if(
                $!iter,                   # if false, we didn't skip
                nqp::stmts(               # skipped a key
                  nqp::shift($!iter),
                  ($!on-value = 1)
                )
              )
            )
        }
        method push-all($target --> IterationEnd) {
            nqp::while(  # doesn't sink
              $!iter,
              nqp::stmts(
                $target.push(nqp::iterkey_s(nqp::shift($!iter))),
                $target.push(nqp::iterval($!iter))
              )
            )
        }
    }
    multi method kv(Map:D:) { Seq.new(KV.new(self)) }

    my class AntiPairs does Rakudo::Iterator::Mappy {
        method pull-one() {
            nqp::if(
              $!iter,
              nqp::stmts(
                nqp::shift($!iter),
                Pair.new( nqp::iterval($!iter), nqp::iterkey_s($!iter) )
              ),
              IterationEnd
            );
        }
        method push-all($target --> IterationEnd) {
            nqp::while(
              $!iter,
              nqp::stmts(  # doesn't sink
                nqp::shift($!iter),
                $target.push(
                  Pair.new( nqp::iterval($!iter), nqp::iterkey_s($!iter) ))
              )
            )
        }
    }
    multi method antipairs(Map:D:) { Seq.new(AntiPairs.new(self)) }

    multi method invert(Map:D:) {
        Seq.new(Rakudo::Iterator.Invert(self.iterator))
    }

    multi method AT-KEY(Map:D: Str:D \key) is raw {
        nqp::ifnull(nqp::atkey($!storage,nqp::unbox_s(key)),Nil)
    }
    multi method AT-KEY(Map:D: \key) is raw {
        nqp::ifnull(nqp::atkey($!storage,nqp::unbox_s(key.Str)),Nil)
    }

    multi method ASSIGN-KEY(Map:D: \key, Mu \value) {
        die nqp::existskey($!storage,key.Str)
          ?? "Cannot change key '{key}' in an immutable {self.^name}"
          !! "Cannot add key '{key}' to an immutable {self.^name}"
    }

    # Directly copy from the other Map's internals: the only thing we need
    # to do, is to decontainerize the values.
    method !STORE_MAP_FROM_MAP(\map --> Nil) {
        nqp::if(
          nqp::elems(my \other := nqp::getattr(map,Map,'$!storage')),
          nqp::stmts(
            (my \iter := nqp::iterator(other)),
            nqp::while(
              iter,
              nqp::bindkey(
                $!storage,
                nqp::iterkey_s(nqp::shift(iter)),
                nqp::decont(nqp::iterval(iter))   # get rid of any containers
              )
            )
          )
        )
    }

    # Directly copy from the Object Hash's internals, but pay respect to the
    # fact that we're only interested in the values (which contain a Pair with
    # the object key and a value that we need to decontainerize.
    method !STORE_MAP_FROM_OBJECT_HASH(\map --> Nil) {
        nqp::if(
          nqp::elems(my \other := nqp::getattr(map,Map,'$!storage')),
          nqp::stmts(
            (my \iter := nqp::iterator(other)),
            nqp::while(
              iter,
              nqp::bindkey(
                $!storage,
                nqp::getattr(
                  (my \pair := nqp::iterval(nqp::shift(iter))),
                  Pair, '$!key'
                ).Str,
                nqp::decont(nqp::getattr(pair,Pair,'$!value'))
              )
            )
          )
        )
    }

    # Copy the contents of a Mappy thing that's not in a container.
    method !STORE_MAP(\map --> Nil) {
        nqp::if(
          nqp::eqaddr(map.keyof,Str(Any)),  # is it not an Object Hash?
          self!STORE_MAP_FROM_MAP(map),
          self!STORE_MAP_FROM_OBJECT_HASH(map)
        )
    }

    # Store the contents of an iterator into the Map
    method !STORE_MAP_FROM_ITERATOR(\iter) is raw {
        nqp::stmts(
          nqp::until(
            nqp::eqaddr((my Mu $x := iter.pull-one),IterationEnd),
            nqp::if(
              nqp::istype($x,Pair),
              nqp::bindkey(
                $!storage,
                nqp::getattr(nqp::decont($x),Pair,'$!key').Str,
                nqp::decont(nqp::getattr(nqp::decont($x),Pair,'$!value'))
              ),
              nqp::if(
                (nqp::istype($x,Map) && nqp::not_i(nqp::iscont($x))),
                self!STORE_MAP($x),
                nqp::if(
                  nqp::eqaddr((my Mu $y := iter.pull-one),IterationEnd),
                  nqp::if(
                    nqp::istype($x,Failure),
                    $x.throw,
                    X::Hash::Store::OddNumber.new(
                      found => self.elems * 2 + 1,
                      last  => $x
                    ).throw
                  ),
                  nqp::bindkey($!storage,$x.Str,nqp::decont($y))
                )
              )
            )
          ),
          self
        )
    }

    method !DECONTAINERIZE() {
        nqp::stmts(
          (my \iter := nqp::iterator($!storage)),
          nqp::while(
            iter,
            nqp::if(
              nqp::iscont(nqp::iterval(nqp::shift(iter))),
              nqp::bindkey(
                $!storage,
                nqp::iterkey_s(iter),
                nqp::decont(nqp::iterval(iter))  # get rid of any containers
              )
            )
          ),
          self
        )
    }

    proto method STORE(|) {*}
    multi method STORE(Map:D: Map:D \map, :$initialize) {
        nqp::if(
          $initialize,
          nqp::if(
            nqp::eqaddr(map.keyof,Str(Any)),  # is it not an Object Hash?
            nqp::if(
              nqp::elems(my \other := nqp::getattr(map,Map,'$!storage')),
              nqp::if(
                nqp::eqaddr(map.WHAT,Map),
                nqp::p6bindattrinvres(self,Map,'$!storage',other),
                nqp::p6bindattrinvres(
                  self,Map,'$!storage',nqp::clone(other)
                )!DECONTAINERIZE
              ),
              self                      # nothing to do
            ),
            nqp::p6bindattrinvres(
              self, Map, '$!storage',
              nqp::p6bindattrinvres(
                nqp::create(self), Map, '$!storage', nqp::hash
              )!STORE_MAP_FROM_OBJECT_HASH(map)
            )
          ),
          X::Assignment::RO.new(value => self).throw
        )
    }
    multi method STORE(Map:D: \to_store, :$initialize) {
        nqp::if(
          $initialize,
          nqp::p6bindattrinvres(
            self, Map, '$!storage',
            nqp::getattr(
              nqp::p6bindattrinvres(
                nqp::create(self), Map, '$!storage', nqp::hash
              )!STORE_MAP_FROM_ITERATOR(to_store.iterator),
              Map, '$!storage'
            )
          ),
          X::Assignment::RO.new(value => self).throw
        )
    }

    method Capture(Map:D:) {
        nqp::p6bindattrinvres(nqp::create(Capture),Capture,'%!hash',$!storage)
    }

    method FLATTENABLE_LIST() { nqp::list() }
    method FLATTENABLE_HASH() {
        $!storage
    }

    method fmt(Map: Cool $format = "%s\t\%s", $sep = "\n") {
        nqp::iseq_i(nqp::sprintfdirectives( nqp::unbox_s($format.Stringy)),1)
          ?? self.keys.fmt($format, $sep)
          !! self.pairs.fmt($format, $sep)
    }

    method hash() { self }
    method clone(Map:D:) is raw { self }

    multi method roll(Map:D:) {
        nqp::if(
          $!storage && nqp::elems($!storage),
          nqp::stmts(
            (my int $i =
              nqp::add_i(nqp::floor_n(nqp::rand_n(nqp::elems($!storage))),1)),
            (my \iter := nqp::iterator($!storage)),
            nqp::while(
              nqp::shift(iter) && ($i = nqp::sub_i($i,1)),
              nqp::null
            ),
            Pair.new(nqp::iterkey_s(iter),nqp::iterval(iter))
          ),
          Nil
        )
    }
    multi method roll(Map:D: Callable:D $calculate) {
        self.roll( $calculate(self.elems) )
    }
    multi method roll(Map:D: Whatever $) { self.roll(Inf) }
    my class RollN does Iterator {
        has $!storage;
        has $!keys;
        has $!pairs;
        has $!count;

        method !SET-SELF(\hash,\count) {
            nqp::stmts(
              ($!storage := nqp::getattr(hash,Map,'$!storage')),
              ($!count = count),
              (my int $i = nqp::elems($!storage)),
              (my \iter := nqp::iterator($!storage)),
              ($!keys := nqp::setelems(nqp::list_s,$i)),
              ($!pairs := nqp::setelems(nqp::list,$i)),
              nqp::while(
                nqp::isge_i(($i = nqp::sub_i($i,1)),0),
                nqp::bindpos_s($!keys,$i,
                  nqp::iterkey_s(nqp::shift(iter)))
              ),
              self
            )
        }
        method new(\h,\c) { nqp::create(self)!SET-SELF(h,c) }
        method pull-one() {
            nqp::if(
              $!count,
              nqp::stmts(
                --$!count,  # must be HLL to handle Inf
                nqp::ifnull(
                  nqp::atpos(
                    $!pairs,
                    (my int $i =
                      nqp::floor_n(nqp::rand_n(nqp::elems($!keys))))
                  ),
                  nqp::bindpos($!pairs,$i,
                    Pair.new(
                      nqp::atpos_s($!keys,$i),
                      nqp::atkey($!storage,nqp::atpos_s($!keys,$i))
                    )
                  )
                )
              ),
              IterationEnd
            )
        }
        method is-lazy() { $!count == Inf }
    }
    multi method roll(Map:D: $count) {
        Seq.new(
          $!storage && nqp::elems($!storage) && $count > 0
            ?? RollN.new(self,$count)
            !! Rakudo::Iterator.Empty
        )
    }

    multi method pick(Map:D:) { self.roll }

    multi method Set(Map:D:)     {
        nqp::create(Set).SET-SELF(Rakudo::QuantHash.COERCE-MAP-TO-SET(self))
    }
    multi method SetHash(Map:D:)     {
        nqp::create(SetHash).SET-SELF(Rakudo::QuantHash.COERCE-MAP-TO-SET(self))
    }
    multi method Bag(Map:D:)     {
        nqp::create(Bag).SET-SELF(Rakudo::QuantHash.COERCE-MAP-TO-BAG(self))
    }
    multi method BagHash(Map:D:)     {
        nqp::create(BagHash).SET-SELF(Rakudo::QuantHash.COERCE-MAP-TO-BAG(self))
    }
    multi method Mix(Map:D:)     {
        nqp::create(Mix).SET-SELF(Rakudo::QuantHash.COERCE-MAP-TO-MIX(self))
    }
    multi method MixHash(Map:D:)     {
        nqp::create(MixHash).SET-SELF(Rakudo::QuantHash.COERCE-MAP-TO-MIX(self))
    }
}

multi sub infix:<eqv>(Map:D \a, Map:D \b) {

    class NotEQV { }

    nqp::p6bool(
      nqp::unless(
        nqp::eqaddr(a,b),
        nqp::if(                                 # not comparing with self
          nqp::eqaddr(a.WHAT,b.WHAT),
          nqp::if(                               # same types
            (my \amap := nqp::getattr(nqp::decont(a),Map,'$!storage'))
              && (my int $elems = nqp::elems(amap)),
            nqp::if(                             # elems on left
              (my \bmap := nqp::getattr(nqp::decont(b),Map,'$!storage'))
                && nqp::iseq_i($elems,nqp::elems(bmap)),
              nqp::stmts(                        # same elems on right
                (my \iter := nqp::iterator(amap)),
                nqp::while(
                  iter && infix:<eqv>(
                    nqp::iterval(nqp::shift(iter)),
                    nqp::ifnull(nqp::atkey(bmap,nqp::iterkey_s(iter)),NotEQV)
                  ),
                  ($elems = nqp::sub_i($elems,1))
                ),
                nqp::not_i($elems)               # ok if none left
              )
            ),
            nqp::isfalse(                        # nothing on left
              (my \map := nqp::getattr(nqp::decont(b),Map,'$!storage'))
                && nqp::elems(map)               # something on right: fail
            )
          )
        )
      )
    )
}

# vim: ft=perl6 expandtab sw=4
